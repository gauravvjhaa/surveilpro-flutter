import 'package:flutter/material.dart';

enum ModelType {
  // Real-ESRGAN models
  realEsrganX2,
  realEsrganX3,
  realEsrganX4,

  // SurveilPro models (HAT-based)
  surveilProX2,
  surveilProX3,
  surveilProX4,
}

extension ModelTypeExtension on ModelType {
  String get name {
    return toString().split('.').last;
  }

  String get displayName {
    switch (this) {
      case ModelType.realEsrganX2: return "Real-ESRGAN";
      case ModelType.realEsrganX3: return "Real-ESRGAN";
      case ModelType.realEsrganX4: return "Real-ESRGAN";
      case ModelType.surveilProX2: return "SurveilPro";
      case ModelType.surveilProX3: return "SurveilPro";
      case ModelType.surveilProX4: return "SurveilPro";
    }
  }

  String get readableName {
    switch (this) {
      case ModelType.realEsrganX2: return "Real-ESRGAN x2";
      case ModelType.realEsrganX3: return "Real-ESRGAN x3";
      case ModelType.realEsrganX4: return "Real-ESRGAN x4";
      case ModelType.surveilProX2: return "SurveilPro x2";
      case ModelType.surveilProX3: return "SurveilPro x3";
      case ModelType.surveilProX4: return "SurveilPro x4";
    }
  }

  String get description {
    switch (this) {
      case ModelType.realEsrganX2:
        return "Best for general images with natural textures, 2× upscaling";
      case ModelType.realEsrganX3:
        return "Best for general images with natural textures, 3× upscaling";
      case ModelType.realEsrganX4:
        return "Best for general images with natural textures, 4× upscaling";
      case ModelType.surveilProX2:
        return "Optimized for surveillance footage with improved detail, 2× upscaling";
      case ModelType.surveilProX3:
        return "Optimized for surveillance footage with improved detail, 3× upscaling";
      case ModelType.surveilProX4:
        return "Optimized for surveillance footage with improved detail, 4× upscaling";
    }
  }

  String get fileName {
    switch (this) {
      case ModelType.realEsrganX2: return "realesrgan_x2plus_float16.tflite"; // Fix this line
      case ModelType.realEsrganX3: return "realesrgan_x2plus_float16.tflite"; // Uses x2 file for x3
      case ModelType.realEsrganX4: return "realesrgan_x4plus_float16.tflite";
      case ModelType.surveilProX2: return "hat_x2_float16.tflite";
      case ModelType.surveilProX3: return "hat_x3_float16.tflite";
      case ModelType.surveilProX4: return "hat_x4_float16.tflite";
    }
  }

  int get scale {
    switch (this) {
      case ModelType.realEsrganX2: return 2;
      case ModelType.realEsrganX3: return 3;
      case ModelType.realEsrganX4: return 4;
      case ModelType.surveilProX2: return 2;
      case ModelType.surveilProX3: return 3;
      case ModelType.surveilProX4: return 4;
    }
  }

  // CONFIGURABLE: Update these sizes with actual values when available
  double get sizeInMB {
    switch (this) {
      case ModelType.realEsrganX2: return 32.2;
      case ModelType.realEsrganX3: return 32.2;
      case ModelType.realEsrganX4: return 32.2;
      case ModelType.surveilProX2: return 78.6;
      case ModelType.surveilProX3: return 78.9;
      case ModelType.surveilProX4: return 78.9;
    }
  }

  // CONFIGURABLE: Replace these URLs with your actual GitHub Release URLs
  String get downloadUrl {
    switch (this) {
      case ModelType.realEsrganX2:
        return "https://github.com/gauravvjhaa/surveilpro-flutter/releases/download/tflitemodels/realesrgan_x2plus_float16.tflite";
      case ModelType.realEsrganX3:
        return "https://github.com/gauravvjhaa/surveilpro-flutter/releases/download/tflitemodels/realesrgan_x3.tflite"; // Not available? fallback link or fix
      case ModelType.realEsrganX4:
        return "https://github.com/gauravvjhaa/surveilpro-flutter/releases/download/tflitemodels/realesrgan_x4plus_float16.tflite";
      case ModelType.surveilProX2:
        return "https://github.com/gauravvjhaa/surveilpro-flutter/releases/download/tflitemodels/hat_x2_float16.tflite";
      case ModelType.surveilProX3:
        return "https://github.com/gauravvjhaa/surveilpro-flutter/releases/download/tflitemodels/hat_x3_float16.tflite";
      case ModelType.surveilProX4:
        return "https://github.com/gauravvjhaa/surveilpro-flutter/releases/download/tflitemodels/hat_x4_float16.tflite";
    }
  }


  // Get appropriate icon for the model type
  IconData get icon {
    switch (this) {
      case ModelType.realEsrganX2:
      case ModelType.realEsrganX3:
      case ModelType.realEsrganX4:
        return Icons.photo_size_select_large;
      case ModelType.surveilProX2:
      case ModelType.surveilProX3:
      case ModelType.surveilProX4:
        return Icons.videocam;
    }
  }

  // Get model family (for grouping in UI)
  String get family {
    switch (this) {
      case ModelType.realEsrganX2:
      case ModelType.realEsrganX3:
      case ModelType.realEsrganX4:
        return "Real-ESRGAN";
      case ModelType.surveilProX2:
      case ModelType.surveilProX3:
      case ModelType.surveilProX4:
        return "SurveilPro";
    }
  }

  // UI color for the model type
  Color get color {
    switch (this) {
      case ModelType.realEsrganX2:
      case ModelType.realEsrganX3:
      case ModelType.realEsrganX4:
        return Colors.blue;
      case ModelType.surveilProX2:
      case ModelType.surveilProX3:
      case ModelType.surveilProX4:
        return Colors.purple;
    }
  }

  // Returns models of the same family with different scales
  List<ModelType> get familyModels {
    switch (this) {
      case ModelType.realEsrganX2:
      case ModelType.realEsrganX3:
      case ModelType.realEsrganX4:
        return [ModelType.realEsrganX2, ModelType.realEsrganX3, ModelType.realEsrganX4];
      case ModelType.surveilProX2:
      case ModelType.surveilProX3:
      case ModelType.surveilProX4:
        return [ModelType.surveilProX2, ModelType.surveilProX3, ModelType.surveilProX4];
    }
  }
}

// Helper methods for working with model types
class ModelHelper {
  // Get all models with a specific scale
  static List<ModelType> getModelsWithScale(int scale) {
    return ModelType.values.where((model) => model.scale == scale).toList();
  }

  // Get models grouped by family
  static Map<String, List<ModelType>> getModelsByFamily() {
    final Map<String, List<ModelType>> result = {};

    for (final model in ModelType.values) {
      if (!result.containsKey(model.family)) {
        result[model.family] = [];
      }
      result[model.family]!.add(model);
    }

    return result;
  }
}