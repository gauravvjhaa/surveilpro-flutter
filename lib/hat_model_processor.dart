import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as developer;
import 'model_types.dart';

class HATModelProcessor {
  static const String ERROR_OUT_OF_MEMORY = 'IMAGE_TOO_LARGE';
  static const String ERROR_MODEL_MISSING = 'MODEL_MISSING';
  static const String ERROR_TFLITE_FAILED = 'TFLITE_ERROR';

  // Static GPU delegate for reuse
  static GpuDelegateV2? _gpuDelegate;

  // Process an image with HAT models
  static Future<File?> processImage({
    required File inputFile,
    required ModelType modelType,
    required int scale,
    Function(double progress, String stage)? onProgress,
  }) async {
    print("🚀 [HAT] Starting HAT image enhancement: scale=${scale}x, model=${modelType.readableName}");

    onProgress?.call(0.0, "Initializing...");
    try {
      // 1. Load the image
      onProgress?.call(0.05, "Loading image...");
      print("📂 [HAT] Loading image from file: ${inputFile.path}");
      final inputBytes = await inputFile.readAsBytes();
      print("📊 [HAT] Image bytes loaded: ${inputBytes.length} bytes");

      onProgress?.call(0.08, "Decoding image...");
      final inputImage = img.decodeImage(inputBytes);
      if (inputImage == null) {
        print("❌ [HAT] Failed to decode input image");
        throw Exception('Failed to decode input image');
      }
      print("🖼️ [HAT] Image decoded successfully: ${inputImage.width}x${inputImage.height}");

      // 2. Check if image is too large
      if (_isImageTooLarge(inputImage, scale)) {
        print("⚠️ [HAT] Image is too large for available memory");
        throw Exception(ERROR_OUT_OF_MEMORY);
      }

      // 3. Load the model
      onProgress?.call(0.1, "Loading AI model...");
      final appDir = await getApplicationDocumentsDirectory();
      final modelFilePath = '${appDir.path}/models/${modelType.fileName}';
      final modelFile = File(modelFilePath);
      print("🤖 [HAT] Looking for model at: $modelFilePath");

      if (!await modelFile.exists()) {
        print("❌ [HAT] Model file not found at: $modelFilePath");
        throw Exception(ERROR_MODEL_MISSING);
      }
      print("✅ [HAT] Model file found: ${await modelFile.length()} bytes");

      // 4. Initialize the interpreter
      Interpreter? interpreter;
      onProgress?.call(0.15, "Initializing AI model...");
      print("🔄 [HAT] Attempting to initialize TFLite interpreter");

      try {
        // Try with GPU acceleration first
        print("🔄 [HAT] Attempt 1: Loading with GPU delegate");
        if (_gpuDelegate == null) {
          try {
            _gpuDelegate = GpuDelegateV2(options: GpuDelegateOptionsV2(
              isPrecisionLossAllowed: true,
            ));
          } catch (e) {
            print("⚠️ [HAT] Error creating GPU delegate: $e");
            _gpuDelegate = null;
          }
        }

        final options = InterpreterOptions()..threads = 2;

        if (_gpuDelegate != null) {
          options.addDelegate(_gpuDelegate!);
        }

        interpreter = await Interpreter.fromFile(modelFile, options: options);
        print("✅ [HAT] Interpreter loaded successfully with GPU support");
      } catch (e) {
        print("⚠️ [HAT] GPU delegate failed: $e");

        try {
          // Try CPU only as fallback
          print("🔄 [HAT] Attempt 2: Loading from file path (CPU only)");
          final options = InterpreterOptions()..threads = 2;
          interpreter = await Interpreter.fromFile(modelFile, options: options);
          print("✅ [HAT] Interpreter loaded successfully from file (CPU)");
        } catch (e) {
          print("⚠️ [HAT] File-based load failed: $e");

          // Last attempt - using buffer instead of file
          try {
            print("🔄 [HAT] Attempt 3: Loading from buffer");
            final modelBuffer = await modelFile.readAsBytes();
            print("📊 [HAT] Model buffer size: ${modelBuffer.length} bytes");
            interpreter = await Interpreter.fromBuffer(modelBuffer);
            print("✅ [HAT] Interpreter loaded successfully from buffer");
          } catch (e) {
            print("❌ [HAT] All TFLite load attempts failed: $e");
            throw Exception(ERROR_TFLITE_FAILED);
          }
        }
      }

      if (interpreter == null) {
        print("❌ [HAT] Interpreter is null after initialization attempts");
        throw Exception('Failed to initialize TFLite interpreter');
      }

      // Print interpreter details for debugging
      final inputTensor = interpreter.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);

      print("📐 [HAT] Input shape: ${inputTensor.shape}");
      print("📐 [HAT] Output shape: ${outputTensor.shape}");
      print("🔤 [HAT] Input type: ${inputTensor.type}");
      print("🔤 [HAT] Output type: ${outputTensor.type}");

      // 5. Process with tiling for memory efficiency
      onProgress?.call(0.2, "Enhancing image...");
      print("🔄 [HAT] Starting image enhancement with tiling");

      final enhancedImage = await _processWithTiling(
        interpreter: interpreter,
        image: inputImage,
        scale: scale,
        onProgress: (tileProgress) {
          // Map tile progress (0-1) to overall progress range (0.2-0.9)
          final overallProgress = 0.2 + (tileProgress * 0.7);
          onProgress?.call(overallProgress, "Enhancing image...");
        },
      );
      print("✅ [HAT] Enhancement complete: ${enhancedImage.width}x${enhancedImage.height}");

      // 6. Save output to file
      onProgress?.call(0.9, "Saving enhanced image...");
      final tempDir = await getTemporaryDirectory();
      final outputFileName = 'hat_enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final outputFile = File('${tempDir.path}/$outputFileName');
      print("📂 [HAT] Saving enhanced image to: ${outputFile.path}");

      // Convert to JPEG and save
      final outputBytes = img.encodeJpg(enhancedImage, quality: 95);
      print("📊 [HAT] Encoded JPEG size: ${outputBytes.length} bytes");
      await outputFile.writeAsBytes(outputBytes);
      print("✅ [HAT] File saved successfully");

      // 7. Clean up
      onProgress?.call(1.0, "Enhancement complete!");
      _safeCloseInterpreter(interpreter);

      return outputFile;

    } catch (e, stackTrace) {
      print("❌ [HAT] Processing error: $e");
      developer.log(
        'Error in HAT model processing',
        error: e,
        stackTrace: stackTrace,
        name: 'hat_processor',
      );

      // Rethrow specific errors
      if (e.toString().contains(ERROR_OUT_OF_MEMORY)) {
        throw Exception(ERROR_OUT_OF_MEMORY);
      } else if (e.toString().contains(ERROR_MODEL_MISSING)) {
        throw Exception(ERROR_MODEL_MISSING);
      } else if (e.toString().contains(ERROR_TFLITE_FAILED)) {
        throw Exception(ERROR_TFLITE_FAILED);
      }

      // For other errors, rethrow
      throw e;
    }
  }

  // Check if an image is too large to process
  static bool _isImageTooLarge(img.Image image, int scale) {
    // Calculate output image size
    final outputPixels = image.width * image.height * scale * scale;

    // 25MP is a reasonable limit for most devices
    return outputPixels > 25000000;
  }

  // Process image using tiling technique with progress tracking
  static Future<img.Image> _processWithTiling({
    required Interpreter interpreter,
    required img.Image image,
    required int scale,
    Function(double progress)? onProgress,
    int tileSize = 128, // HAT models usually work better with smaller tiles
    int overlap = 16,   // Overlap for seamless blending
  }) async {
    print("🧩 [HAT-Tiling] Starting tiling process");
    print("📊 [HAT-Tiling] Input image: ${image.width}x${image.height}, scale: $scale");

    try {
      // Create output image
      final outWidth = image.width * scale;
      final outHeight = image.height * scale;
      print("📐 [HAT-Tiling] Output dimensions: ${outWidth}x${outHeight}");

      final outputImage = img.Image(width: outWidth, height: outHeight);
      print("✅ [HAT-Tiling] Output image created");

      // Calculate number of tiles
      final numTilesX = (image.width + tileSize - 1) ~/ tileSize;
      final numTilesY = (image.height + tileSize - 1) ~/ tileSize;
      final totalTiles = numTilesX * numTilesY;
      print("🧮 [HAT-Tiling] Tile grid: ${numTilesX}x${numTilesY} (total: $totalTiles)");

      // Track processed tiles for progress
      int processedTiles = 0;

      // Process each tile
      for (int ty = 0; ty < numTilesY; ty++) {
        for (int tx = 0; tx < numTilesX; tx++) {
          // Update progress
          processedTiles++;
          final progress = processedTiles / totalTiles;
          onProgress?.call(progress);

          print("🧩 [HAT-Tiling] Processing tile $processedTiles/$totalTiles at ($tx, $ty) - ${(progress * 100).toInt()}%");

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

          if (tileWidth <= 0 || tileHeight <= 0) {
            print("⚠️ [HAT-Tiling] Skipping invalid tile dimensions");
            continue;
          }

          // Extract tile
          print("✂️ [HAT-Tiling] Cropping tile from position ($x0, $y0): ${tileWidth}x${tileHeight}");
          final tile = img.copyCrop(image, x: x0, y: y0, width: tileWidth, height: tileHeight);

          // Process tile
          print("🔄 [HAT-Tiling] Processing tile with HAT model");
          final processedTile = await _processTile(
            interpreter: interpreter,
            tile: tile,
            scale: scale,
          );
          print("✅ [HAT-Tiling] Tile processed: ${processedTile.width}x${processedTile.height}");

          // Calculate output coordinates
          final outX0 = x0 * scale;
          final outY0 = y0 * scale;

          // Determine which parts of this tile are not overlapped by subsequent tiles
          int effectiveWidth = tileWidth;
          int effectiveHeight = tileHeight;

          if (tx < numTilesX - 1) {
            effectiveWidth = min(tileWidth, tileSize);
          }

          if (ty < numTilesY - 1) {
            effectiveHeight = min(tileHeight, tileSize);
          }

          // Copy processed tile to output image
          print("🔄 [HAT-Tiling] Copying processed tile to output image");
          for (int y = 0; y < effectiveHeight * scale; y++) {
            for (int x = 0; x < effectiveWidth * scale; x++) {
              if (x < processedTile.width &&
                  y < processedTile.height &&
                  outX0 + x < outputImage.width &&
                  outY0 + y < outputImage.height) {
                outputImage.setPixel(outX0 + x, outY0 + y, processedTile.getPixel(x, y));
              }
            }
          }
        }
      }

      print("✅ [HAT-Tiling] All tiles processed successfully");
      return outputImage;

    } catch (e) {
      print("❌ [HAT-Tiling] Error in tiling process: $e");

      // Check if this is a memory error
      if (e.toString().contains('memory') || e.toString().contains('OutOfMemory')) {
        throw Exception(ERROR_OUT_OF_MEMORY);
      }

      // Fallback to simple resize if tiling fails
      print("⚠️ [HAT-Tiling] Using fallback resize method");
      return img.copyResize(
        image,
        width: image.width * scale,
        height: image.height * scale,
        interpolation: img.Interpolation.cubic,
      );
    }
  }

  // Process a single tile using the HAT model
  static Future<img.Image> _processTile({
    required Interpreter interpreter,
    required img.Image tile,
    required int scale,
  }) async {
    try {
      // Get shape information from the model
      final inputShape = interpreter.getInputTensor(0).shape;
      final outputShape = interpreter.getOutputTensor(0).shape;

      print("📐 [HAT] Input shape: $inputShape, Output shape: $outputShape");

      // Get the model's expected input dimensions
      final batchSize = inputShape[0];
      final expectedHeight = inputShape[1];
      final expectedWidth = inputShape[2];
      final channels = inputShape[3];

      // Resize the input to match what the model expects
      final resizedTile = img.copyResize(
          tile,
          width: expectedWidth,
          height: expectedHeight,
          interpolation: img.Interpolation.cubic
      );

      print("🔄 [HAT] Resized input from ${tile.width}x${tile.height} to ${expectedWidth}x${expectedHeight}");

      // Create input tensor - HAT models expect input in range [-1, 1]
      final input = List.generate(
        batchSize,
            (_) => List.generate(
          expectedHeight,
              (y) => List.generate(
            expectedWidth,
                (x) {
              final pixel = resizedTile.getPixel(x, y);
              return [
                (pixel.r / 255.0) * 2 - 1, // R channel normalized to [-1, 1]
                (pixel.g / 255.0) * 2 - 1, // G channel normalized to [-1, 1]
                (pixel.b / 255.0) * 2 - 1  // B channel normalized to [-1, 1]
              ];
            },
          ),
        ),
      );
      print("✅ [HAT] Created input tensor with shape [${batchSize}, ${expectedHeight}, ${expectedWidth}, ${channels}]");

      // Create output tensor
      final outputHeight = outputShape[1];
      final outputWidth = outputShape[2];

      final output = List.generate(
        batchSize,
            (_) => List.generate(
          outputHeight,
              (_) => List.generate(
            outputWidth,
                (_) => List<double>.filled(channels, 0),
          ),
        ),
      );
      print("✅ [HAT] Created output tensor with shape [${batchSize}, ${outputHeight}, ${outputWidth}, ${channels}]");

      // Run inference
      print("🚀 [HAT] Running TFLite inference");
      interpreter.run(input, output);
      print("✅ [HAT] Inference completed successfully");

      // Create output image at the model's output size
      final modelOutputImage = img.Image(width: outputWidth, height: outputHeight);

      // Convert output tensor to image - HAT models output in [-1, 1] range
      for (int y = 0; y < outputHeight; y++) {
        for (int x = 0; x < outputWidth; x++) {
          final r = ((output[0][y][x][0] + 1) / 2 * 255).round().clamp(0, 255);
          final g = ((output[0][y][x][1] + 1) / 2 * 255).round().clamp(0, 255);
          final b = ((output[0][y][x][2] + 1) / 2 * 255).round().clamp(0, 255);
          modelOutputImage.setPixelRgba(x, y, r, g, b, 255);
        }
      }

      // Resize to match the desired output size (original × scale)
      final finalWidth = tile.width * scale;
      final finalHeight = tile.height * scale;
      print("🔄 [HAT] Resizing output from ${outputWidth}x${outputHeight} to ${finalWidth}x${finalHeight}");

      // Final resize to match the expected output dimensions
      if (modelOutputImage.width != finalWidth || modelOutputImage.height != finalHeight) {
        return img.copyResize(
            modelOutputImage,
            width: finalWidth,
            height: finalHeight,
            interpolation: img.Interpolation.cubic
        );
      } else {
        return modelOutputImage;
      }

    } catch (e) {
      print("❌ [HAT] Error in tile processing: $e");

      // Fallback to simple resize
      return img.copyResize(
        tile,
        width: tile.width * scale,
        height: tile.height * scale,
        interpolation: img.Interpolation.cubic,
      );
    }
  }

  // Safe interpreter closure to prevent crashes
  static void _safeCloseInterpreter(Interpreter? interpreter) {
    if (interpreter == null) {
      print("⚠️ [HAT] Tried to close null interpreter");
      return;
    }

    // Store reference and set to null immediately to prevent double-closing
    final localInterpreter = interpreter;
    interpreter = null;

    try {
      print("🧹 [HAT] Closing interpreter");

      // Wrap close in a delayed Future to allow GPU operations to complete
      Future.microtask(() {
        try {
          localInterpreter.close();
          print("✅ [HAT] Interpreter closed successfully");
        } catch (e) {
          print("⚠️ [HAT] Delayed close failed: $e");
          // Already did our best to clean up
        }
      });
    } catch (e) {
      print("⚠️ [HAT] Error in safe close: $e");
    }
  }

  // Dispose resources
  static void dispose() {
    try {
      final localDelegate = _gpuDelegate;
      _gpuDelegate = null;

      if (localDelegate != null) {
        // Dispose with a slight delay to ensure no active operations
        Future.delayed(Duration(milliseconds: 100), () {
          try {
            localDelegate.delete();
            print("✅ [HAT] GPU delegate disposed");
          } catch (e) {
            print("⚠️ [HAT] Error disposing GPU delegate: $e");
          }
        });
      }
    } catch (e) {
      print("⚠️ [HAT] Error in dispose method: $e");
    }
  }
}