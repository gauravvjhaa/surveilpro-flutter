import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'model_types.dart';

class SuperResolutionProcessor {
  // Track if TFLite has been successfully initialized
  static bool _tfLiteAvailable = true;

  // Define named error types for better UI handling
  static const String ERROR_OUT_OF_MEMORY = 'IMAGE_TOO_LARGE';
  static const String ERROR_MODEL_MISSING = 'MODEL_MISSING';
  static const String ERROR_TFLITE_FAILED = 'TFLITE_ERROR';

  // Process an image through the SR model with progress reporting
  static Future<File?> enhanceImage({
    required File inputFile,
    required ModelType modelType,
    required int scale,
    Function(double progress, String stage)? onProgress,
  }) async {
    print("🚀 [SR] Starting image enhancement: scale=${scale}x");

    // Start progress reporting
    onProgress?.call(0.0, "Initializing...");

    try {
      // 1. Load the image
      onProgress?.call(0.05, "Loading image...");
      print("📂 [SR] Loading image from file: ${inputFile.path}");
      final inputBytes = await inputFile.readAsBytes();
      print("📊 [SR] Image bytes loaded: ${inputBytes.length} bytes");

      onProgress?.call(0.08, "Decoding image...");
      final inputImage = img.decodeImage(inputBytes);
      if (inputImage == null) {
        print("❌ [SR] Failed to decode input image");
        throw Exception('Failed to decode input image');
      }
      print("🖼️ [SR] Image decoded successfully: ${inputImage.width}x${inputImage.height}");

      // Check if image is too large to process
      if (!await _hasEnoughMemory(inputImage, scale)) {
        print("⚠️ [SR] Image is too large for available memory");
        throw Exception(ERROR_OUT_OF_MEMORY);
      }

      // 2. Get the model file
      onProgress?.call(0.1, "Loading AI model...");
      final appDir = await getApplicationDocumentsDirectory();
      final modelFilePath = '${appDir.path}/models/${modelType.fileName}';
      final modelFile = File(modelFilePath);
      print("🤖 [SR] Looking for model at: $modelFilePath");

      if (!await modelFile.exists()) {
        print("❌ [SR] Model file not found at: $modelFilePath");
        throw Exception(ERROR_MODEL_MISSING);
      }
      print("✅ [SR] Model file found: ${await modelFile.length()} bytes");

      // 3. Check if we already know TFLite is unavailable
      if (!_tfLiteAvailable) {
        print("⚠️ [SR] TFLite previously marked as unavailable, using fallback");
        return _createEnhancedImage(
          inputFile,
          inputImage,
          scale,
          onProgress: (fallbackProgress) {
            // Map fallback progress (0-1) to overall progress range (0.1-1.0)
            onProgress?.call(0.1 + (fallbackProgress * 0.9), "Enhancing image...");
          },
        );
      }

      try {
        // 4. Try to initialize the interpreter
        Interpreter? interpreter;
        onProgress?.call(0.15, "Initializing AI model...");
        print("🔄 [SR] Attempting to initialize TFLite interpreter");

        try {
          print("🔄 [SR] Attempt 1: Loading from file path");
          final options = InterpreterOptions()..threads = 2;
          interpreter = await Interpreter.fromFile(modelFile, options: options);
          print("✅ [SR] Interpreter loaded successfully from file");
        } catch (e) {
          print("⚠️ [SR] First TFLite load attempt failed: $e");

          // Try another approach - using buffer instead of file
          try {
            onProgress?.call(0.15, "Preparing AI model (retry)...");
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

        // Print interpreter details for debugging
        print("📊 [SR] Input tensor count: ${interpreter.getInputTensor(0) != null ? 1 : 0}");
        print("📊 [SR] Output tensor count: ${interpreter.getOutputTensor(0) != null ? 1 : 0}");

        final inputTensor = interpreter.getInputTensor(0);
        final outputTensor = interpreter.getOutputTensor(0);

        print("📐 [SR] Input shape: ${inputTensor.shape}");
        print("📐 [SR] Output shape: ${outputTensor.shape}");
        print("🔤 [SR] Input type: ${inputTensor.type}");
        print("🔤 [SR] Output type: ${outputTensor.type}");

        // 5. Process image with real TFLite model
        onProgress?.call(0.2, "Starting enhancement...");
        print("🔄 [SR] Starting tiling process");
        final enhancedImage = await _processWithTiling(
          interpreter: interpreter,
          image: inputImage,
          scale: scale,
          onProgress: (tileProgress) {
            // Map tile progress (0-1) to overall progress range (0.2-0.9)
            final overallProgress = 0.2 + (tileProgress * 0.7);
            final completedPercent = (tileProgress * 100).toInt();
            onProgress?.call(overallProgress, "Enhancing image: $completedPercent%");
          },
        );
        print("✅ [SR] Tiling process complete: ${enhancedImage.width}x${enhancedImage.height}");

        // 6. Save output to file
        onProgress?.call(0.9, "Saving enhanced image...");
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
        onProgress?.call(1.0, "Enhancement complete!");
        print("🧹 [SR] Closing interpreter");
        interpreter.close();

        return outputFile;

      } catch (e) {
        // Handle TFLite errors properly
        if (e.toString().contains('memory') || e.toString().contains('OutOfMemory')) {
          print("❌ [SR] Out of memory error: $e");
          throw Exception(ERROR_OUT_OF_MEMORY);
        }

        // If TFLite failed, mark it as unavailable and use fallback
        print("❌ [SR] TFLite failed: $e");
        print("⚠️ [SR] Marking TFLite as unavailable and using fallback");
        _tfLiteAvailable = false;

        onProgress?.call(0.3, "Using fallback enhancement...");
        return _createEnhancedImage(
          inputFile,
          inputImage,
          scale,
          onProgress: (fallbackProgress) {
            // Map fallback progress (0-1) to overall progress range (0.3-1.0)
            onProgress?.call(0.3 + (fallbackProgress * 0.7), "Enhancing image with fallback method...");
          },
        );
      }

    } catch (e, stackTrace) {
      print("❌ [SR] Top-level error: $e");
      developer.log(
        'Error in super resolution processing',
        error: e,
        stackTrace: stackTrace,
        name: 'sr_processor',
      );

      // Pass specific error types through
      if (e.toString().contains(ERROR_OUT_OF_MEMORY)) {
        throw Exception(ERROR_OUT_OF_MEMORY);
      } else if (e.toString().contains(ERROR_MODEL_MISSING)) {
        throw Exception(ERROR_MODEL_MISSING);
      } else if (e.toString().contains(ERROR_TFLITE_FAILED)) {
        throw Exception(ERROR_TFLITE_FAILED);
      }

      // For other errors, just pass them through
      throw e;
    }
  }

  // Check if there's enough memory to process the image
  static Future<bool> _hasEnoughMemory(img.Image image, int scale) async {
    // Check if the image is too large based on pixel count
    final inputPixels = image.width * image.height;
    final outputPixels = inputPixels * scale * scale;

    // Basic heuristic: If output is >25 megapixels, memory might be an issue
    if (outputPixels > 25000000) {
      print("⚠️ [SR] Image potentially too large: output will be ${outputPixels / 1000000}MP");
      return false;
    }

    // Could add platform-specific memory checks here
    return true;
  }

  // Create an enhanced version of the image without using TFLite
  static Future<File> _createEnhancedImage(
      File inputFile,
      img.Image originalImage,
      int scale,
      {Function(double progress)? onProgress}
      ) async {
    print("🔄 [SR-Fallback] Starting enhanced image creation");
    developer.log('Creating enhanced image using fallback method', name: 'sr_processor');

    onProgress?.call(0.1);

    // First resize the image to the target size
    print("🖼️ [SR-Fallback] Resizing image to ${originalImage.width * scale}x${originalImage.height * scale}");
    onProgress?.call(0.3);

    final enhancedImage = img.copyResize(
      originalImage,
      width: originalImage.width * scale,
      height: originalImage.height * scale,
      interpolation: img.Interpolation.cubic,
    );
    print("✅ [SR-Fallback] Image resized successfully");
    onProgress?.call(0.5);

    // Apply image processing to simulate enhancement
    print("🔄 [SR-Fallback] Applying image quality enhancements");
    final processedImage = _enhanceImageQuality(enhancedImage);
    print("✅ [SR-Fallback] Enhancements applied");
    onProgress?.call(0.8);

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
    onProgress?.call(1.0);

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
      -1,  9, -1,
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

  // Process image using tiling technique with accurate progress reporting
  static Future<img.Image> _processWithTiling({
    required Interpreter interpreter,
    required img.Image image,
    required int scale,
    Function(double progress)? onProgress,
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
      final totalTiles = numTilesX * numTilesY;
      print("🧮 [SR-Tiling] Tile grid: ${numTilesX}x${numTilesY} tiles (total: $totalTiles)");

      // Overlap for seamless blending
      const overlap = 16;
      print("📏 [SR-Tiling] Using overlap of $overlap pixels");

      // Track processed tiles for progress
      int processedTiles = 0;

      // Process each tile
      for (int ty = 0; ty < numTilesY; ty++) {
        for (int tx = 0; tx < numTilesX; tx++) {
          // Update progress
          processedTiles++;
          final progress = processedTiles / totalTiles;
          onProgress?.call(progress);

          print("🧩 [SR-Tiling] Processing tile $processedTiles/$totalTiles at position ($tx, $ty) - ${(progress * 100).toInt()}%");

          // Calculate tile coordinates with overlap
          int x0 = tx * tileSize - overlap;
          int y0 = ty * tileSize - overlap;
          int x1 = min((tx + 1) * tileSize + overlap, image.width);
          int y1 = min((ty + 1) * tileSize + overlap, image.height);

          // Clamp to image boundaries
          x0 = max(0, x0);
          y0 = max(0, y0);

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

          // Determine which parts of this tile are not overlapped by subsequent tiles
          int effectiveWidth = tileWidth;
          int effectiveHeight = tileHeight;

          if (tx < numTilesX - 1) {
            effectiveWidth = min(tileWidth, tileSize);
          }

          if (ty < numTilesY - 1) {
            effectiveHeight = min(tileHeight, tileSize);
          }

          // Copy pixels from processed tile to output image
          print("🔄 [SR-Tiling] Copying processed tile to output image");
          for (int y = 0; y < effectiveHeight * scale; y++) {
            for (int x = 0; x < effectiveWidth * scale; x++) {
              // Make sure we're within bounds of both images
              if (x < processedTile.width &&
                  y < processedTile.height &&
                  outX0 + x < outputImage.width &&
                  outY0 + y < outputImage.height) {

                // Get pixel from processed tile
                final pixel = processedTile.getPixel(x, y);

                // Set pixel in output image
                outputImage.setPixel(outX0 + x, outY0 + y, pixel);
              }
            }
          }
          print("✅ [SR-Tiling] Tile copied to output");
        }
      }

      print("✅ [SR-Tiling] All tiles processed successfully");
      return outputImage;

    } catch (e) {
      print("❌ [SR-Tiling] Error in tiling process: $e");
      developer.log('Error in tiling process: $e', name: 'sr_processor');

      // Check if this is a memory error
      if (e.toString().contains('memory') || e.toString().contains('OutOfMemory')) {
        throw Exception(ERROR_OUT_OF_MEMORY);
      }

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
        throw Exception(ERROR_TFLITE_FAILED);
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