import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../model_types.dart';
import 'dart:developer' as developer;

class ModelInfo {
  final ModelType type;
  bool isDownloaded;
  double? downloadProgress;
  bool isDownloading;

  ModelInfo({
    required this.type,
    this.isDownloaded = false,
    this.downloadProgress,
    this.isDownloading = false,
  });
}

class ModelManager extends ChangeNotifier {
  bool isInitialized = false;
  String? errorMessage;

  // All available models with download status
  late List<ModelInfo> allModels;

  // Image model selections
  ModelType? imageModelX2;
  ModelType? imageModelX3;
  ModelType? imageModelX4;

  // Video model selections
  ModelType? videoModelX2;
  ModelType? videoModelX3;
  ModelType? videoModelX4;

  // Track if preferences are being saved
  bool isSaving = false;

  ModelManager() {
    // Initialize model list
    allModels = ModelType.values.map((type) =>
        ModelInfo(type: type)
    ).toList();
  }

  Future<void> initialize() async {
    try {
      // Check which models are downloaded
      await _checkDownloadedModels();

      // Load model preferences from SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Load preferences but constrain them to downloaded models
      imageModelX2 = await _ensureModelAvailable(_getModelTypeFromPrefs(prefs, 'image_model_x2', null));
      imageModelX3 = await _ensureModelAvailable(_getModelTypeFromPrefs(prefs, 'image_model_x3', null));
      imageModelX4 = await _ensureModelAvailable(_getModelTypeFromPrefs(prefs, 'image_model_x4', null));
      videoModelX2 = await _ensureModelAvailable(_getModelTypeFromPrefs(prefs, 'video_model_x2', null));
      videoModelX3 = await _ensureModelAvailable(_getModelTypeFromPrefs(prefs, 'video_model_x3', null));
      videoModelX4 = await _ensureModelAvailable(_getModelTypeFromPrefs(prefs, 'video_model_x4', null));

      isInitialized = true;
      notifyListeners();
    } catch (e, stackTrace) {
      developer.log(
        'Error initializing model manager',
        error: e,
        stackTrace: stackTrace,
        name: 'model_manager',
      );
      errorMessage = 'Failed to initialize model manager: $e';
      isInitialized = true; // Still mark as initialized to prevent infinite retries
      notifyListeners();
    }
  }

  // Check if a model is actually available, otherwise return null
  Future<ModelType?> _ensureModelAvailable(ModelType? modelType) async {
    if (modelType == null) return null;

    final isAvailable = await isModelDownloaded(modelType);
    if (isAvailable) {
      return modelType;
    }
    return null;
  }

  ModelType? _getModelTypeFromPrefs(SharedPreferences prefs, String key, ModelType? defaultValue) {
    try {
      final value = prefs.getString(key);
      if (value == null) return defaultValue;

      return ModelType.values.firstWhere(
            (element) => element.name == value,
        orElse: () => throw Exception('Model type not found'),
      );
    } catch (e) {
      developer.log('Error getting preference for $key: $e', name: 'model_manager');
      return defaultValue;
    }
  }

  // New method to update preferences immediately
  Future<void> updateModelPreference({
    required bool isVideo,
    required int scale,
    required ModelType? model
  }) async {
    // Update in-memory state immediately
    if (isVideo) {
      switch (scale) {
        case 2: videoModelX2 = model; break;
        case 3: videoModelX3 = model; break;
        case 4: videoModelX4 = model; break;
      }
    } else {
      switch (scale) {
        case 2: imageModelX2 = model; break;
        case 3: imageModelX3 = model; break;
        case 4: imageModelX4 = model; break;
      }
    }

    // Notify listeners to update UI
    notifyListeners();

    // Also save to persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = isVideo ? 'video_model_x$scale' : 'image_model_x$scale';

      if (model != null) {
        await prefs.setString(key, model.name);
      } else {
        await prefs.remove(key);
      }
    } catch (e) {
      developer.log('Error saving preference: $e', name: 'model_manager');
      // Don't throw error since the in-memory update already happened
    }
  }

  Future<void> saveSettings() async {
    if (isSaving) return; // Prevent multiple simultaneous saves

    isSaving = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();

      // Only save values if they're not null (meaning model is downloaded)
      if (imageModelX2 != null) {
        await prefs.setString('image_model_x2', imageModelX2!.name);
      }
      if (imageModelX3 != null) {
        await prefs.setString('image_model_x3', imageModelX3!.name);
      }
      if (imageModelX4 != null) {
        await prefs.setString('image_model_x4', imageModelX4!.name);
      }
      if (videoModelX2 != null) {
        await prefs.setString('video_model_x2', videoModelX2!.name);
      }
      if (videoModelX3 != null) {
        await prefs.setString('video_model_x3', videoModelX3!.name);
      }
      if (videoModelX4 != null) {
        await prefs.setString('video_model_x4', videoModelX4!.name);
      }
    } catch (e, stackTrace) {
      developer.log(
        'Error saving settings',
        error: e,
        stackTrace: stackTrace,
        name: 'model_manager',
      );
      errorMessage = 'Failed to save settings: $e';
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  // MODEL DOWNLOADING FUNCTIONALITY

  // Get the directory where models are stored
  Future<Directory> get modelsDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    return modelsDir;
  }

  // Check which models are already downloaded
  Future<void> _checkDownloadedModels() async {
    final dir = await modelsDir;

    for (final model in allModels) {
      final file = File('${dir.path}/${model.type.fileName}');
      model.isDownloaded = await file.exists();
    }
  }

  // Check if a specific model is downloaded
  Future<bool> isModelDownloaded(ModelType modelType) async {
    final dir = await modelsDir;
    final file = File('${dir.path}/${modelType.fileName}');
    return await file.exists();
  }

  // Get model file if it exists
  Future<File?> getModelFile(ModelType modelType) async {
    final dir = await modelsDir;
    final file = File('${dir.path}/${modelType.fileName}');

    if (await file.exists()) {
      return file;
    }
    return null;
  }

  // Download a model
  Future<bool> downloadModel(ModelType modelType) async {
    final modelInfo = allModels.firstWhere(
          (info) => info.type == modelType,
    );

    if (modelInfo.isDownloading) return false;

    modelInfo.isDownloading = true;
    modelInfo.downloadProgress = 0.0;
    notifyListeners();

    try {
      final dir = await modelsDir;
      final file = File('${dir.path}/${modelType.fileName}');

      // Create the client and request
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(modelType.downloadUrl));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      int bytesReceived = 0;

      final List<int> bytes = [];

      // Listen to the response stream
      await response.stream.forEach((List<int> newBytes) {
        bytes.addAll(newBytes);
        bytesReceived += newBytes.length;

        if (contentLength > 0) {
          final progress = bytesReceived / contentLength;
          modelInfo.downloadProgress = progress;
          notifyListeners();
        }
      });

      // Write the file when download completes
      await file.writeAsBytes(bytes);

      modelInfo.isDownloaded = true;
      modelInfo.isDownloading = false;
      modelInfo.downloadProgress = null;
      notifyListeners();

      client.close();
      return true;
    } catch (e, stackTrace) {
      developer.log(
        'Error downloading model',
        error: e,
        stackTrace: stackTrace,
        name: 'model_manager',
      );

      modelInfo.isDownloading = false;
      modelInfo.downloadProgress = null;
      notifyListeners();
      return false;
    }
  }

  // Delete a model
  Future<bool> deleteModel(ModelType modelType) async {
    try {
      // Reset model preferences if needed
      if (imageModelX2 == modelType) imageModelX2 = null;
      if (imageModelX3 == modelType) imageModelX3 = null;
      if (imageModelX4 == modelType) imageModelX4 = null;
      if (videoModelX2 == modelType) videoModelX2 = null;
      if (videoModelX3 == modelType) videoModelX3 = null;
      if (videoModelX4 == modelType) videoModelX4 = null;

      final dir = await modelsDir;
      final file = File('${dir.path}/${modelType.fileName}');

      if (await file.exists()) {
        await file.delete();
      }

      // Update model status
      final modelInfo = allModels.firstWhere(
            (info) => info.type == modelType,
      );

      modelInfo.isDownloaded = false;
      notifyListeners();

      // Update shared preferences to remove deleted model
      await saveSettings();

      return true;
    } catch (e) {
      developer.log('Error deleting model: $e', name: 'model_manager');
      return false;
    }
  }

  // Get model for specific enhancement
  Future<ModelType?> getModelForEnhancement({required bool isVideo, required int scale}) async {
    ModelType? model;

    switch (scale) {
      case 2:
        model = isVideo ? videoModelX2 : imageModelX2;
        break;
      case 3:
        model = isVideo ? videoModelX3 : imageModelX3;
        break;
      case 4:
        model = isVideo ? videoModelX4 : imageModelX4;
        break;
      default:
        model = null;
    }

    // Verify model is downloaded
    if (model != null && await isModelDownloaded(model)) {
      return model;
    }

    return null;
  }

  // Get storage usage statistics
  Future<Map<String, dynamic>> getStorageStats() async {
    try {
      final dir = await modelsDir;

      int totalSizeBytes = 0;

      await for (var entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalSizeBytes += await entity.length();
        }
      }

      // Get free space - this is platform-specific and simplified here
      final appDir = await getApplicationDocumentsDirectory();
      final stat = await appDir.stat();
      final freeSpaceGB = ((stat.size ?? 0) / (1024 * 1024 * 1024)).toStringAsFixed(1);

      return {
        'used': (totalSizeBytes / (1024 * 1024)).toStringAsFixed(1),
        'free': freeSpaceGB,
      };
    } catch (e) {
      return {
        'used': '0.0',
        'free': 'unknown',
      };
    }
  }

  // Get available model types (downloaded only)
  List<ModelType> get downloadedModelTypes {
    return allModels
        .where((info) => info.isDownloaded)
        .map((info) => info.type)
        .toList();
  }
}