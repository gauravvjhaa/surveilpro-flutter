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

  String get description {
    switch (this) {
      case ModelType.realESRGAN:
        return 'Best for natural photos with good general performance';
      case ModelType.hat:
        return 'Transformer-based model with good detail preservation';
      case ModelType.hatL:
        return 'Larger HAT model with better quality but slower performance';
      case ModelType.hatGAN:
        return 'Combines transformer and GAN approaches for more realistic textures';
      case ModelType.hatOCR:
        return 'Specialized for text and document enhancement with better text clarity';
    }
  }

  double get sizeMB {
    switch (this) {
      case ModelType.realESRGAN:
        return 14.3;
      case ModelType.hat:
        return 11.8;
      case ModelType.hatL:
        return 22.5;
      case ModelType.hatGAN:
        return 17.4;
      case ModelType.hatOCR:
        return 16.2;
    }
  }

  String get downloadUrl {
    switch (this) {
      case ModelType.realESRGAN:
        return 'https://cfpziwcfrmygnmvsmhum.supabase.co/storage/v1/object/public/modelzoo/realesrgan_x4plus_float16.tflite';
      case ModelType.hat:
        return 'https://example.com/models/hat.tflite'; // Replace with actual URL when available
      case ModelType.hatL:
        return 'https://example.com/models/hat_l.tflite'; // Replace with actual URL when available
      case ModelType.hatGAN:
        return 'https://example.com/models/hat_gan.tflite'; // Replace with actual URL when available
      case ModelType.hatOCR:
        return 'https://example.com/models/hat_ocr.tflite'; // Replace with actual URL when available
    }
  }

  String get fileName {
    switch (this) {
      case ModelType.realESRGAN:
        return 'realesrgan_x4plus_float16.tflite';
      case ModelType.hat:
        return 'hat.tflite';
      case ModelType.hatL:
        return 'hat_l.tflite';
      case ModelType.hatGAN:
        return 'hat_gan.tflite';
      case ModelType.hatOCR:
        return 'hat_ocr.tflite';
    }
  }
}