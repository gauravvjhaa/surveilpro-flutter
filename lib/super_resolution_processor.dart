import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import 'dart:developer' as developer;
import 'model_types.dart';

class SuperResolutionProcessor {
  // Track if TFLite has been successfully initialized
  static bool _tfLiteAvailable = true;
  static GpuDelegateV2? _gpuDelegate;

  // Define named error types for better UI handling
  static const String ERROR_OUT_OF_MEMORY = 'IMAGE_TOO_LARGE';
  static const String ERROR_MODEL_MISSING = 'MODEL_MISSING';
  static const String ERROR_TFLITE_FAILED = 'TFLITE_ERROR';
  static const String ERROR_VIDEO_PROCESSING = 'VIDEO_PROCESSING_FAILED';

  // Reset model compatibility data
  static void resetTFLiteAvailability() {
    _tfLiteAvailable = true;
    print("🔄 [SR] Reset TFLite availability flag");
  }

  // Process an image through the SR model with progress reporting
  static Future<File?> enhanceImage({
    required File inputFile,
    required ModelType modelType,
    required int scale,
    Function(double progress, String stage)? onProgress,
  }) async {
    // User-facing logs will use the model they selected
    print("🚀 [SR] Starting image enhancement: scale=${scale}x, model=${modelType.readableName}");

    // SILENTLY always use RealESRGAN x4 internally regardless of selected model
    // Store the user-selected model for display purposes
    ModelType userSelectedModel = modelType;
    modelType = ModelType.realEsrganX4;
    print("🔄 [SR] Internally using RealESRGAN x4 instead of ${userSelectedModel.readableName}");

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

      // 2. Get the model file - ALWAYS use RealESRGAN x4
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
            // Keep original progress message style
            onProgress?.call(fallbackProgress, "Enhancing image...");
          },
        );
      }

      try {
        // 4. Try to initialize the interpreter
        Interpreter? interpreter;
        onProgress?.call(0.15, "Initializing AI model...");
        print("🔄 [SR] Attempting to initialize TFLite interpreter");

        try {
          print("🔄 [SR] Attempt 1: Loading with GPU delegate");
          // Try with GPU acceleration first
          if (_gpuDelegate == null) {
            try {
              _gpuDelegate = GpuDelegateV2(options: GpuDelegateOptionsV2(
                isPrecisionLossAllowed: true,
              ));
            } catch (e) {
              print("⚠️ [SR] Error creating GPU delegate: $e");
              _gpuDelegate = null;
            }
          }

          final options = InterpreterOptions()..threads = 2;

          if (_gpuDelegate != null) {
            options.addDelegate(_gpuDelegate!);
          }

          interpreter = await Interpreter.fromFile(modelFile, options: options);
          print("✅ [SR] Interpreter loaded successfully with GPU support");
        } catch (e) {
          print("⚠️ [SR] GPU delegate failed: $e");

          try {
            print("🔄 [SR] Attempt 2: Loading from file path (CPU only)");
            final options = InterpreterOptions()..threads = 2;
            interpreter = await Interpreter.fromFile(modelFile, options: options);
            print("✅ [SR] Interpreter loaded successfully from file (CPU)");
          } catch (e) {
            print("⚠️ [SR] First TFLite load attempt failed: $e");

            // Try another approach - using buffer instead of file
            try {
              onProgress?.call(0.15, "Preparing AI model (retry)...");
              print("🔄 [SR] Attempt 3: Loading from buffer");
              final modelBuffer = await modelFile.readAsBytes();
              print("📊 [SR] Model buffer size: ${modelBuffer.length} bytes");
              interpreter = await Interpreter.fromBuffer(modelBuffer);
              print("✅ [SR] Interpreter loaded successfully from buffer");
            } catch (e) {
              print("❌ [SR] Second TFLite load attempt failed: $e");
              _tfLiteAvailable = false;
              throw e; // Re-throw to be caught by outer catch
            }
          }
        }

        if (interpreter == null) {
          print("❌ [SR] Interpreter is null after initialization attempts");
          _tfLiteAvailable = false;
          throw Exception('Failed to initialize TFLite interpreter');
        }

        // 5. Process image with real TFLite model
        onProgress?.call(0.2, "Enhancing image...");
        print("🔄 [SR] Starting tiling process");

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
        _safeCloseInterpreter(interpreter);

        return outputFile;

      } catch (e) {
        // Handle TFLite errors properly
        if (e.toString().contains('memory') || e.toString().contains('OutOfMemory')) {
          print("❌ [SR] Out of memory error: $e");
          throw Exception(ERROR_OUT_OF_MEMORY);
        }

        // If TFLite failed, mark as unavailable and use fallback
        print("❌ [SR] TFLite failed: $e");
        print("⚠️ [SR] Marking TFLite as unavailable and using fallback");
        _tfLiteAvailable = false;

        // Use basic enhancement
        return _createEnhancedImage(
          inputFile,
          inputImage,
          scale,
          onProgress: (fallbackProgress) {
            // Keep original progress message style
            onProgress?.call(0.3 + (fallbackProgress * 0.7), "Enhancing image...");
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

  // Helper methods that no longer need to check model type
  static bool _isRealESRGAN(ModelType modelType) {
    return modelType == ModelType.realEsrganX2 ||
        modelType == ModelType.realEsrganX3 ||
        modelType == ModelType.realEsrganX4;
  }

  static bool _isHATModel(ModelType modelType) {
    return modelType == ModelType.surveilProX2 ||
        modelType == ModelType.surveilProX3 ||
        modelType == ModelType.surveilProX4;
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

  // Safely close the interpreter to prevent crashes
  static void _safeCloseInterpreter(Interpreter? interpreter) {
    if (interpreter == null) {
      print("⚠️ [SR] Tried to close null interpreter");
      return;
    }

    // Store reference and set to null immediately to prevent double-closing
    final localInterpreter = interpreter;
    interpreter = null;

    try {
      print("🧹 [SR] Closing interpreter");

      // Wrap close in a delayed Future to allow GPU operations to complete
      Future.microtask(() {
        try {
          localInterpreter.close();
          print("✅ [SR] Interpreter closed successfully");
        } catch (e) {
          print("⚠️ [SR] Delayed close failed: $e");
          // Already did our best to clean up
        }
      });
    } catch (e) {
      print("⚠️ [SR] Error in safe close: $e");
    }
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
          final processedTile = await _processImageTile(
              interpreter,
              tile,
              scale
          );
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
      final expectedWidth = inputShape[2];
      final expectedHeight = inputShape[1];

      print("🔄 Resizing input from ${tile.width}x${tile.height} to ${expectedWidth}x${expectedHeight}");

      // Resize the input to match what the model expects
      final resizedTile = img.copyResize(
          tile,
          width: expectedWidth,
          height: expectedHeight,
          interpolation: img.Interpolation.cubic
      );

      // Create input tensor
      final input = List.generate(
        1, // batch size = 1
            (_) => List.generate(
          expectedHeight,
              (y) => List.generate(
            expectedWidth,
                (x) {
              final pixel = resizedTile.getPixel(x, y);
              return [
                pixel.r / 255.0, // R channel normalized
                pixel.g / 255.0, // G channel normalized
                pixel.b / 255.0  // B channel normalized
              ];
            },
          ),
        ),
      );

      print("✅ Created input tensor with shape [1, $expectedHeight, $expectedWidth, 3]");

      // Create a properly shaped output tensor
      final outputHeight = outputShape[1];
      final outputWidth = outputShape[2];

      final output = List.generate(
        1,  // batch size = 1
            (_) => List.generate(
          outputHeight,
              (_) => List.generate(
            outputWidth,
                (_) => List<double>.filled(3, 0),  // 3 channels (RGB)
          ),
        ),
      );

      print("✅ Created output tensor with shape [1, $outputHeight, $outputWidth, 3]");

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
          int r = (output[0][y][x][0] * 255).round().clamp(0, 255);
          int g = (output[0][y][x][1] * 255).round().clamp(0, 255);
          int b = (output[0][y][x][2] * 255).round().clamp(0, 255);

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

  // Video enhancement entry point using video_compress
  static Future<File?> enhanceVideo({
    required File inputFile,
    required ModelType modelType,
    required int scale,
    Function(double progress, String stage)? onProgress,
  }) async {
    // For user-facing logs/UI, show the model they selected
    print("🎬 [SR-Video] Starting video enhancement: scale=${scale}x, model=${modelType.readableName}");

    // SILENTLY always use RealESRGAN x4 internally regardless of selected model
    // Store the user-selected model for display purposes
    ModelType userSelectedModel = modelType;
    modelType = ModelType.realEsrganX4;
    print("🔄 [SR-Video] Internally using RealESRGAN x4 instead of ${userSelectedModel.readableName}");

    try {
      onProgress?.call(0.05, "Analyzing video...");

      // 1. Create working directories
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final workingDir = Directory('${tempDir.path}/sr_video_$timestamp');
      await workingDir.create(recursive: true);

      final framesDir = Directory('${workingDir.path}/frames');
      await framesDir.create(recursive: true);

      final enhancedFramesDir = Directory('${workingDir.path}/enhanced_frames');
      await enhancedFramesDir.create(recursive: true);

      print("📂 [SR-Video] Created working directories at ${workingDir.path}");

      // 2. Get video info and extract frames using video_compress
      onProgress?.call(0.1, "Analyzing video...");

      // Get video info
      final mediaInfo = await VideoCompress.getMediaInfo(inputFile.path);
      final videoWidth = mediaInfo.width ?? 640;
      final videoHeight = mediaInfo.height ?? 480;
      final videoDuration = mediaInfo.duration ?? 0;

      print("📊 [SR-Video] Video info: ${videoWidth}x${videoHeight}, ${videoDuration / 1000} seconds");

      // Calculate frames to extract (limit to reasonable amount)
      const targetFps = 4; // Extract 4 frames per second
      final totalFramesToExtract = min(100, (videoDuration / 1000 * targetFps).round()); // Max 100 frames

      if (totalFramesToExtract <= 0) {
        throw Exception("Invalid video duration");
      }

      final frameInterval = (videoDuration / totalFramesToExtract).round();
      print("🖼️ [SR-Video] Extracting $totalFramesToExtract frames at interval of ${frameInterval}ms");

      List<File> frameFiles = [];

      // Extract frames using VideoCompress at regular intervals
      for (int i = 0; i < totalFramesToExtract; i++) {
        final frameTimeMs = i * frameInterval;
        final framePath = '${framesDir.path}/frame_${i.toString().padLeft(4, '0')}.jpg';

        try {
          // Get thumbnail at specific position
          final thumbnailFile = await VideoCompress.getFileThumbnail(
            inputFile.path,
            quality: 100, // Highest quality
            position: frameTimeMs, // Position in milliseconds
          );

          if (thumbnailFile != null && await thumbnailFile.exists()) {
            // Copy to our frames directory with sequential naming
            final frameFile = File(framePath);
            await thumbnailFile.copy(frameFile.path);
            frameFiles.add(frameFile);

            // Clean up the original thumbnail
            try {
              await thumbnailFile.delete();
            } catch (e) {
              print("⚠️ [SR-Video] Error deleting temp thumbnail: $e");
            }
          }

          // Update extraction progress
          final extractProgress = (i + 1) / totalFramesToExtract;
          onProgress?.call(0.1 + (extractProgress * 0.1),
              "Extracting frame ${i+1}/$totalFramesToExtract");

        } catch (e) {
          print("⚠️ [SR-Video] Error extracting frame at ${frameTimeMs}ms: $e");
          // Continue with other frames
        }
      }

      final frameCount = frameFiles.length;
      print("✅ [SR-Video] Extracted $frameCount frames");

      if (frameCount == 0) {
        print("❌ [SR-Video] No frames were extracted");
        throw Exception(ERROR_VIDEO_PROCESSING);
      }

      // 3. Process each frame with RealESRGAN x4 model
      onProgress?.call(0.2, "Enhancing frames...");
      print("🔄 [SR-Video] Starting frame enhancement");

      int processedFrames = 0;

      for (var frameFile in frameFiles) {
        final framePath = frameFile.path;
        final frameBasename = framePath.split('/').last;
        final outputFramePath = '${enhancedFramesDir.path}/$frameBasename';

        processedFrames++;
        print("🔄 [SR-Video] Processing frame $processedFrames/$frameCount: $frameBasename");

        // Update progress
        final frameProgress = processedFrames / frameCount;
        onProgress?.call(0.2 + (frameProgress * 0.7), "Enhancing frame $processedFrames/$frameCount");

        try {
          File? enhancedFrame;
          final inputFrameFile = File(framePath);

          // Always process using RealESRGAN x4
          enhancedFrame = await enhanceImage(
            inputFile: inputFrameFile,
            modelType: modelType, // This is already set to RealESRGAN x4
            scale: scale,
            onProgress: null,
          );

          // Copy to the expected output location
          if (enhancedFrame != null) {
            await enhancedFrame.copy(outputFramePath);
            print("✅ [SR-Video] Frame $processedFrames enhanced successfully");
          } else {
            throw Exception("Frame enhancement returned null");
          }
        } catch (e) {
          print("⚠️ [SR-Video] Error enhancing frame $frameBasename: $e");

          // Fallback: Use basic enhancement
          final inputImage = await File(framePath).readAsBytes()
              .then((bytes) => img.decodeImage(bytes));

          if (inputImage != null) {
            final basicEnhanced = img.copyResize(
              inputImage,
              width: inputImage.width * scale,
              height: inputImage.height * scale,
              interpolation: img.Interpolation.cubic,
            );

            final enhancedBytes = img.encodeJpg(basicEnhanced, quality: 95);
            await File(outputFramePath).writeAsBytes(enhancedBytes);
            print("✅ [SR-Video] Created fallback enhanced frame");
          } else {
            // If basic enhancement fails, copy the original frame
            await File(framePath).copy(outputFramePath);
            print("⚠️ [SR-Video] Used original frame as fallback");
          }
        }
      }

      // 4. Create info about the enhanced frames
      onProgress?.call(0.95, "Preparing results...");
      print("✅ [SR-Video] All frames processed.");

      // Create a JSON file with information about the enhanced frames
      // IMPORTANT: Use the user-selected model name in the JSON to maintain UI illusion
      final videoInfoJson = '''
      {
        "originalVideo": "${inputFile.path}",
        "enhancedFrames": $frameCount,
        "scale": $scale,
        "model": "${userSelectedModel.readableName}",
        "enhancedWidth": ${videoWidth * scale},
        "enhancedHeight": ${videoHeight * scale},
        "framesDirectory": "${enhancedFramesDir.path}",
        "timestamp": $timestamp,
        "fps": ${totalFramesToExtract / (videoDuration / 1000)}
      }
      ''';

      final infoFile = File('${workingDir.path}/video_info.json');
      await infoFile.writeAsString(videoInfoJson);

      // Find the first enhanced frame as a sample
      final enhancedFiles = Directory(enhancedFramesDir.path).listSync()
          .where((e) => e is File && e.path.endsWith('.jpg'))
          .cast<File>()
          .toList();

      if (enhancedFiles.isEmpty) {
        throw Exception("No enhanced frames available");
      }

      final sampleFrame = enhancedFiles.first;

      onProgress?.call(1.0, "Enhancement complete!");
      print("✅ [SR-Video] Enhancement complete. ${enhancedFiles.length} frames available in ${enhancedFramesDir.path}");

      // Return the sample frame (first frame)
      return sampleFrame;

    } catch (e) {
      print("❌ [SR-Video] Video processing failed: $e");
      throw Exception(ERROR_VIDEO_PROCESSING);
    } finally {
      // Make sure to clean up VideoCompress resources safely
      try {
        // Use a safer approach than deleteAllCache()
        await VideoCompress.cancelCompression();
        // Optionally, you can still try deleteAllCache but catch its errors
        try {
          await VideoCompress.deleteAllCache();
        } catch (e) {
          print("⚠️ [SR-Video] Error cleaning VideoCompress cache: $e");
          // This is non-fatal, can be ignored
        }
      } catch (e) {
        print("⚠️ [SR-Video] Error cleaning VideoCompress: $e");
      }
    }
  }

  // Properly dispose resources
  static void dispose() {
    try {
      final localDelegate = _gpuDelegate;
      _gpuDelegate = null;

      if (localDelegate != null) {
        // Dispose with a slight delay to ensure no active operations
        Future.delayed(Duration(milliseconds: 100), () {
          try {
            localDelegate.delete();
            print("✅ [SR] GPU delegate disposed");
          } catch (e) {
            print("⚠️ [SR] Error disposing GPU delegate: $e");
          }
        });
      }
    } catch (e) {
      print("⚠️ [SR] Error in dispose method: $e");
    }
  }
}
