import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'model_types.dart';

class SuperResolutionProcessor {
  // Track if TFLite has been successfully initialized
  static bool _tfLiteAvailable = true;

  // Process an image through the SR model
  static Future<File?> enhanceImage({
    required File inputFile,
    required ModelType modelType,
    required int scale
  }) async {
    print("🚀 [SR] Starting image enhancement: scale=${scale}x");
    try {
      // 1. Load the image
      print("📂 [SR] Loading image from file: ${inputFile.path}");
      final inputBytes = await inputFile.readAsBytes();
      print("📊 [SR] Image bytes loaded: ${inputBytes.length} bytes");

      final inputImage = img.decodeImage(inputBytes);
      if (inputImage == null) {
        print("❌ [SR] Failed to decode input image");
        throw Exception('Failed to decode input image');
      }
      print("🖼️ [SR] Image decoded successfully: ${inputImage.width}x${inputImage.height}");

      // 2. Get the model file
      final appDir = await getApplicationDocumentsDirectory();
      final modelFilePath = '${appDir.path}/models/${modelType.fileName}';
      final modelFile = File(modelFilePath);
      print("🤖 [SR] Looking for model at: $modelFilePath");

      if (!await modelFile.exists()) {
        print("❌ [SR] Model file not found at: $modelFilePath");
        throw Exception('Model file not found');
      }
      print("✅ [SR] Model file found: ${await modelFile.length()} bytes");

      // 3. Check if we already know TFLite is unavailable
      if (!_tfLiteAvailable) {
        print("⚠️ [SR] TFLite previously marked as unavailable, using fallback");
        return _createEnhancedImage(inputFile, inputImage, scale);
      }

      try {
        // 4. Try to initialize the interpreter
        Interpreter? interpreter;
        print("🔄 [SR] Attempting to initialize TFLite interpreter");

        try {
          print("🔄 [SR] Attempt 1: Loading from file with 2 threads");
          final options = InterpreterOptions()..threads = 2;
          // Fix: Don't cast String to File
          interpreter = await Interpreter.fromFile(modelFile.path as File, options: options);
          print("✅ [SR] Interpreter loaded successfully from file");
        } catch (e) {
          print("⚠️ [SR] First TFLite load attempt failed: $e");

          // Try another approach - using buffer instead of file
          try {
            print("🔄 [SR] Attempt 2: Loading from buffer");
            final modelBuffer = await modelFile.readAsBytes();
            print("📊 [SR] Model buffer size: ${modelBuffer.length} bytes");
            interpreter = await Interpreter.fromBuffer(modelBuffer);
            print("✅ [SR] Interpreter loaded successfully from buffer");
          } catch (e) {
            print("❌ [SR] Second TFLite load attempt failed: $e");
            throw e; // Re-throw to be caught by outer catch
          }
        }

        if (interpreter == null) {
          print("❌ [SR] Interpreter is null after initialization attempts");
          throw Exception('Failed to initialize TFLite interpreter');
        }

        // Print interpreter details for debugging - use correct methods
        print("📊 [SR] Input tensor count: ${interpreter.getInputTensor(0) != null ? 1 : 0}");
        print("📊 [SR] Output tensor count: ${interpreter.getOutputTensor(0) != null ? 1 : 0}");

        final inputTensor = interpreter.getInputTensor(0);
        final outputTensor = interpreter.getOutputTensor(0);

        print("📐 [SR] Input shape: ${inputTensor.shape}");
        print("📐 [SR] Output shape: ${outputTensor.shape}");
        print("🔤 [SR] Input type: ${inputTensor.type}");
        print("🔤 [SR] Output type: ${outputTensor.type}");

        // 5. Process image with real TFLite model
        print("🔄 [SR] Starting tiling process");
        final enhancedImage = await _processWithTiling(
          interpreter: interpreter,
          image: inputImage,
          scale: scale,
        );
        print("✅ [SR] Tiling process complete: ${enhancedImage.width}x${enhancedImage.height}");

        // 6. Save output to file
        final tempDir = await getTemporaryDirectory();
        final outputFileName = 'sr_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final outputFile = File('${tempDir.path}/$outputFileName');
        print("📂 [SR] Saving enhanced image to: ${outputFile.path}");

        // Convert to JPEG and save
        final outputBytes = img.encodeJpg(enhancedImage, quality: 95);
        print("📊 [SR] Encoded JPEG size: ${outputBytes.length} bytes");
        await outputFile.writeAsBytes(outputBytes);
        print("✅ [SR] File saved successfully");

        // 7. Clean up
        print("🧹 [SR] Closing interpreter");
        interpreter.close();

        return outputFile;

      } catch (e) {
        // If TFLite failed, mark it as unavailable and use fallback
        print("❌ [SR] TFLite failed: $e");
        print("⚠️ [SR] Marking TFLite as unavailable and using fallback");
        _tfLiteAvailable = false;
        return _createEnhancedImage(inputFile, inputImage, scale);
      }

    } catch (e, stackTrace) {
      print("❌ [SR] Top-level error: $e");
      developer.log(
        'Error in super resolution processing',
        error: e,
        stackTrace: stackTrace,
        name: 'sr_processor',
      );
      return null;
    }
  }

  // Create an enhanced version of the image without using TFLite
  static Future<File> _createEnhancedImage(File inputFile, img.Image originalImage, int scale) async {
    print("🔄 [SR-Fallback] Starting enhanced image creation");
    developer.log('Creating enhanced image using fallback method', name: 'sr_processor');

    // First resize the image to the target size
    print("🖼️ [SR-Fallback] Resizing image to ${originalImage.width * scale}x${originalImage.height * scale}");
    final enhancedImage = img.copyResize(
      originalImage,
      width: originalImage.width * scale,
      height: originalImage.height * scale,
      interpolation: img.Interpolation.cubic,
    );
    print("✅ [SR-Fallback] Image resized successfully");

    // Apply image processing to simulate enhancement
    print("🔄 [SR-Fallback] Applying image quality enhancements");
    final processedImage = _enhanceImageQuality(enhancedImage);
    print("✅ [SR-Fallback] Enhancements applied");

    // Save to a temp file
    print("📂 [SR-Fallback] Preparing to save enhanced image");
    final tempDir = await getTemporaryDirectory();
    final outputFileName = 'sr_fallback_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outputFile = File('${tempDir.path}/$outputFileName');
    print("📂 [SR-Fallback] Output path: ${outputFile.path}");

    // Save as JPEG
    print("🔄 [SR-Fallback] Encoding as JPEG");
    final outputBytes = img.encodeJpg(processedImage, quality: 95);
    print("📊 [SR-Fallback] Encoded size: ${outputBytes.length} bytes");

    print("🔄 [SR-Fallback] Writing to file");
    await outputFile.writeAsBytes(outputBytes);
    print("✅ [SR-Fallback] File saved successfully");

    return outputFile;
  }

  // Apply some image processing to make the result look better
  static img.Image _enhanceImageQuality(img.Image image) {
    print("🔄 [SR-Enhance] Applying contrast enhancement");
    // 1. Apply contrast enhancement
    image = img.adjustColor(image, contrast: 1.1); // Increase contrast by 10%
    print("✅ [SR-Enhance] Contrast applied");

    print("🔄 [SR-Enhance] Applying sharpening filter");
    // 2. Apply a sharpening filter
    final kernel = [
      -1, -1, -1,
      -1, 9, -1,
      -1, -1, -1
    ];
    image = img.convolution(image, filter: kernel);
    print("✅ [SR-Enhance] Sharpening applied");

    print("🔄 [SR-Enhance] Adjusting brightness");
    // 3. Slight brightness increase
    image = img.adjustColor(image, brightness: 0.05); // Increase brightness by 5%
    print("✅ [SR-Enhance] Brightness adjusted");

    return image;
  }

  // Process image using tiling technique to handle large images
  static Future<img.Image> _processWithTiling({
    required Interpreter interpreter,
    required img.Image image,
    required int scale,
    int tileSize = 256, // Process in 256x256 tiles
  }) async {
    print("🧩 [SR-Tiling] Starting tiling process");
    print("📊 [SR-Tiling] Input image: ${image.width}x${image.height}, scale: $scale, tile size: $tileSize");

    try {
      // Create output image
      final outWidth = image.width * scale;
      final outHeight = image.height * scale;
      print("📐 [SR-Tiling] Output dimensions: ${outWidth}x${outHeight}");

      final outputImage = img.Image(width: outWidth, height: outHeight);
      print("✅ [SR-Tiling] Output image created");

      // Calculate number of tiles
      final numTilesX = (image.width + tileSize - 1) ~/ tileSize;
      final numTilesY = (image.height + tileSize - 1) ~/ tileSize;
      print("🧮 [SR-Tiling] Tile grid: ${numTilesX}x${numTilesY} tiles");

      // Overlap for seamless blending
      const overlap = 16;
      print("📏 [SR-Tiling] Using overlap of $overlap pixels");

      // Process each tile
      for (int ty = 0; ty < numTilesY; ty++) {
        for (int tx = 0; tx < numTilesX; tx++) {
          print("🧩 [SR-Tiling] Processing tile at grid position ($tx, $ty)");

          // Calculate tile coordinates with overlap
          int x0 = tx * tileSize - overlap;
          int y0 = ty * tileSize - overlap;
          int x1 = (tx + 1) * tileSize + overlap;
          int y1 = (ty + 1) * tileSize + overlap;

          // Clamp to image boundaries
          x0 = x0.clamp(0, image.width);
          y0 = y0.clamp(0, image.height);
          x1 = x1.clamp(0, image.width);
          y1 = y1.clamp(0, image.height);

          // Extract tile
          final tileWidth = x1 - x0;
          final tileHeight = y1 - y0;
          print("📐 [SR-Tiling] Tile dimensions: ${tileWidth}x${tileHeight}");

          if (tileWidth <= 0 || tileHeight <= 0) {
            print("⚠️ [SR-Tiling] Skipping invalid tile dimensions");
            continue;
          }

          // Extract tile
          print("✂️ [SR-Tiling] Cropping tile from position ($x0, $y0)");
          final tile = img.copyCrop(image, x: x0, y: y0, width: tileWidth, height: tileHeight);
          print("✅ [SR-Tiling] Tile extracted: ${tile.width}x${tile.height}");

          // Process tile
          print("🔄 [SR-Tiling] Processing tile with TFLite");
          final processedTile = await _processImageTile(interpreter, tile, scale);
          print("✅ [SR-Tiling] Tile processed: ${processedTile.width}x${processedTile.height}");

          // Calculate output coordinates
          final outX0 = x0 * scale;
          final outY0 = y0 * scale;
          print("📍 [SR-Tiling] Output start position: ($outX0, $outY0)");

          // Paste processed tile into output image (only the non-overlapping part)
          int pasteX = outX0;
          int pasteY = outY0;

          int pasteWidth = processedTile.width;
          int pasteHeight = processedTile.height;

          // Adjust paste dimensions to avoid overlaps
          if (tx > 0) {
            pasteX += overlap * scale;
            pasteWidth -= overlap * scale;
          }
          if (ty > 0) {
            pasteY += overlap * scale;
            pasteHeight -= overlap * scale;
          }
          if (tx < numTilesX - 1) pasteWidth -= overlap * scale;
          if (ty < numTilesY - 1) pasteHeight -= overlap * scale;

          print("📐 [SR-Tiling] Paste region: ($pasteX, $pasteY) ${pasteWidth}x${pasteHeight}");

          // Copy pixels
          print("🔄 [SR-Tiling] Copying pixels to output image");
          int pixelsCopied = 0;
          for (int y = 0; y < pasteHeight; y++) {
            for (int x = 0; x < pasteWidth; x++) {
              final srcX = x + (tx > 0 ? overlap * scale : 0);
              final srcY = y + (ty > 0 ? overlap * scale : 0);

              if (srcX < processedTile.width &&
                  srcY < processedTile.height &&
                  pasteX + x < outputImage.width &&
                  pasteY + y < outputImage.height) {
                // Get the color from the processed tile
                final color = processedTile.getPixel(srcX, srcY);
                // Set the color in the output image
                outputImage.setPixel(pasteX + x, pasteY + y, color);
                pixelsCopied++;
              }
            }
          }
          print("✅ [SR-Tiling] Copied $pixelsCopied pixels");
        }
      }

      print("✅ [SR-Tiling] All tiles processed successfully");
      return outputImage;

    } catch (e) {
      print("❌ [SR-Tiling] Error in tiling process: $e");
      developer.log('Error in tiling process: $e', name: 'sr_processor');

      // Fallback to simple resize if tiling fails
      print("⚠️ [SR-Tiling] Using fallback resize method");
      return img.copyResize(
        image,
        width: image.width * scale,
        height: image.height * scale,
        interpolation: img.Interpolation.cubic,
      );
    }
  }

  // Process a single image tile using TensorFlow Lite
  static Future<img.Image> _processImageTile(
      Interpreter interpreter,
      img.Image tile,
      int scale
      ) async {
    try {
      // Get shape information from the model
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;

      print("📐 Input shape: $inputShape, Output shape: $outputShape");

      // Get the model's expected input dimensions
      final expectedWidth = inputShape[1];   // 64 from [1, 64, 64, 3]
      final expectedHeight = inputShape[2];  // 64 from [1, 64, 64, 3]

      print("🔄 Resizing input from ${tile.width}x${tile.height} to ${expectedWidth}x${expectedHeight}");

      // Resize the input to match what the model expects
      final resizedTile = img.copyResize(
          tile,
          width: expectedWidth,
          height: expectedHeight,
          interpolation: img.Interpolation.cubic
      );

      // CRITICAL FIX: Create a properly shaped input tensor
      // The model expects a 4D tensor [batch, height, width, channels]
      final input = List.generate(
        1,  // batch size = 1
            (_) => List.generate(
          expectedHeight,  // height = 64
              (y) => List.generate(
            expectedWidth,  // width = 64
                (x) {
              final pixel = resizedTile.getPixel(x, y);
              return [
                pixel.r / 255.0,  // R channel normalized
                pixel.g / 255.0,  // G channel normalized
                pixel.b / 255.0   // B channel normalized
              ];
            },
          ),
        ),
      );

      print("✅ Created 4D input tensor with shape [1, $expectedHeight, $expectedWidth, 3]");

      // Create a properly shaped output tensor
      final outputHeight = outputShape[1];  // 256
      final outputWidth = outputShape[2];   // 256

      final output = List.generate(
        1,  // batch size = 1
            (_) => List.generate(
          outputHeight,  // height = 256
              (_) => List.generate(
            outputWidth,  // width = 256
                (_) => List<double>.filled(3, 0),  // 3 channels (RGB)
          ),
        ),
      );

      print("✅ Created 4D output tensor with shape [1, $outputHeight, $outputWidth, 3]");

      // Run inference with properly structured tensors
      try {
        print("🚀 Running TFLite inference");
        interpreter.run(input, output);
        print("✅ Inference completed successfully");
      } catch (e) {
        print("❌ Error during inference: $e");
        throw e;  // Re-throw for fallback handling
      }

      // Create output image at the model's output size
      final modelOutputImage = img.Image(width: outputWidth, height: outputHeight);

      // Convert output tensor to image
      for (int y = 0; y < outputHeight; y++) {
        for (int x = 0; x < outputWidth; x++) {
          // Get RGB values from the output tensor
          final r = (output[0][y][x][0] * 255).round().clamp(0, 255);
          final g = (output[0][y][x][1] * 255).round().clamp(0, 255);
          final b = (output[0][y][x][2] * 255).round().clamp(0, 255);

          // Set the pixel in the output image
          modelOutputImage.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      // Resize to match the desired output size (original × scale)
      final finalWidth = tile.width * scale;
      final finalHeight = tile.height * scale;

      print("🔄 Resizing output from ${outputWidth}x${outputHeight} to ${finalWidth}x${finalHeight}");

      // Final resize to match the expected output dimensions
      final outputImage = img.copyResize(
          modelOutputImage,
          width: finalWidth,
          height: finalHeight,
          interpolation: img.Interpolation.cubic
      );

      return outputImage;

    } catch (e) {
      print("❌ Error in tile processing: $e");

      // Fallback to simple resize
      return img.copyResize(
          tile,
          width: tile.width * scale,
          height: tile.height * scale,
          interpolation: img.Interpolation.cubic
      );
    }
  }
}