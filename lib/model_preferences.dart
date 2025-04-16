import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

enum ModelType {
  realESRGAN,
  hat,
  hatL,
  hatGAN,
  hatOCR,
}

extension ModelTypeExtension on ModelType {
  String get displayName {
    switch (this) {
      case ModelType.realESRGAN:
        return 'RealESRGAN';
      case ModelType.hat:
        return 'HAT';
      case ModelType.hatL:
        return 'HAT-L';
      case ModelType.hatGAN:
        return 'HAT+GAN';
      case ModelType.hatOCR:
        return 'HAT+OCR';
    }
  }
}

class ModelPreferences {
  // Singleton pattern
  static final ModelPreferences _instance = ModelPreferences._internal();
  factory ModelPreferences() => _instance;
  ModelPreferences._internal();

  // Cache the preferences to avoid excessive disk access
  SharedPreferences? _cachedPrefs;

  Future<SharedPreferences> _getPrefs() async {
    _cachedPrefs ??= await SharedPreferences.getInstance();
    return _cachedPrefs!;
  }

  Future<ModelType> getModelForScale({
    required bool isVideo,
    required int scale,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key = isVideo
          ? 'video_model_x$scale'
          : 'image_model_x$scale';

      final modelName = prefs.getString(key);
      if (modelName == null) return ModelType.hatOCR;

      return ModelType.values.firstWhere(
            (element) => element.name == modelName,
        orElse: () => ModelType.hatOCR,
      );
    } catch (e) {
      developer.log('Error getting model preference: $e', name: 'model_preferences');
      return ModelType.hatOCR; // Default to HAT+OCR on any error
    }
  }
}