import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:developer' as developer;

// Define the model types
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

/// A robust storage solution that handles platform exceptions with SharedPreferences
class ModelStorage {
  static final ModelStorage _instance = ModelStorage._internal();
  factory ModelStorage() => _instance;

  // In-memory fallback storage
  final Map<String, String> _memoryStorage = {};

  // Flag to track if device storage is available
  bool _useMemoryFallback = false;

  ModelStorage._internal();

  /// Initialize storage system - call this from main.dart
  Future<void> initialize() async {
    try {
      // Test if SharedPreferences is working
      final prefs = await SharedPreferences.getInstance();
      await prefs.getString('test_key');
      _useMemoryFallback = false;
    } catch (e) {
      developer.log('SharedPreferences failed, using memory storage',
          name: 'ModelStorage', error: e);
      _useMemoryFallback = true;
    }

    // Pre-populate with defaults if needed
    _setDefaultsIfNeeded();
  }

  void _setDefaultsIfNeeded() {
    // Default image models
    _ensureDefault('image_model_x2', ModelType.hatOCR.name);
    _ensureDefault('image_model_x3', ModelType.hatOCR.name);
    _ensureDefault('image_model_x4', ModelType.hatOCR.name);

    // Default video models
    _ensureDefault('video_model_x2', ModelType.hatOCR.name);
    _ensureDefault('video_model_x3', ModelType.hatOCR.name);
    _ensureDefault('video_model_x4', ModelType.hatOCR.name);
  }

  void _ensureDefault(String key, String defaultValue) {
    if (_useMemoryFallback && !_memoryStorage.containsKey(key)) {
      _memoryStorage[key] = defaultValue;
    }
  }

  /// Get a model preference safely
  Future<ModelType> getModelForScale({
    required bool isVideo,
    required int scale,
  }) async {
    final key = isVideo ? 'video_model_x$scale' : 'image_model_x$scale';

    try {
      String? value;

      if (_useMemoryFallback) {
        value = _memoryStorage[key];
      } else {
        final prefs = await SharedPreferences.getInstance();
        value = prefs.getString(key);
      }

      if (value == null) return ModelType.hatOCR;

      return ModelType.values.firstWhere(
            (element) => element.name == value,
        orElse: () => ModelType.hatOCR,
      );
    } catch (e) {
      developer.log('Error getting model preference: $e', name: 'ModelStorage');
      return ModelType.hatOCR;
    }
  }

  /// Save a model preference safely
  Future<bool> setModelForScale({
    required bool isVideo,
    required int scale,
    required ModelType value,
  }) async {
    final key = isVideo ? 'video_model_x$scale' : 'image_model_x$scale';

    try {
      if (_useMemoryFallback) {
        _memoryStorage[key] = value.name;
        return true;
      } else {
        final prefs = await SharedPreferences.getInstance();
        return await prefs.setString(key, value.name);
      }
    } catch (e) {
      developer.log('Error saving model preference: $e', name: 'ModelStorage');

      // Fall back to memory storage if device storage fails
      _useMemoryFallback = true;
      _memoryStorage[key] = value.name;
      return false;
    }
  }

  /// Save all model preferences at once
  Future<bool> saveAllModelPreferences({
    required ModelType imageModelX2,
    required ModelType imageModelX3,
    required ModelType imageModelX4,
    required ModelType videoModelX2,
    required ModelType videoModelX3,
    required ModelType videoModelX4,
  }) async {
    try {
      if (_useMemoryFallback) {
        _memoryStorage['image_model_x2'] = imageModelX2.name;
        _memoryStorage['image_model_x3'] = imageModelX3.name;
        _memoryStorage['image_model_x4'] = imageModelX4.name;
        _memoryStorage['video_model_x2'] = videoModelX2.name;
        _memoryStorage['video_model_x3'] = videoModelX3.name;
        _memoryStorage['video_model_x4'] = videoModelX4.name;
        return true;
      } else {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('image_model_x2', imageModelX2.name);
        await prefs.setString('image_model_x3', imageModelX3.name);
        await prefs.setString('image_model_x4', imageModelX4.name);
        await prefs.setString('video_model_x2', videoModelX2.name);
        await prefs.setString('video_model_x3', videoModelX3.name);
        await prefs.setString('video_model_x4', videoModelX4.name);

        return true;
      }
    } catch (e) {
      developer.log('Error saving all model preferences: $e', name: 'ModelStorage');

      // Fall back to memory storage
      _useMemoryFallback = true;

      _memoryStorage['image_model_x2'] = imageModelX2.name;
      _memoryStorage['image_model_x3'] = imageModelX3.name;
      _memoryStorage['image_model_x4'] = imageModelX4.name;
      _memoryStorage['video_model_x2'] = videoModelX2.name;
      _memoryStorage['video_model_x3'] = videoModelX3.name;
      _memoryStorage['video_model_x4'] = videoModelX4.name;

      return false;
    }
  }
}