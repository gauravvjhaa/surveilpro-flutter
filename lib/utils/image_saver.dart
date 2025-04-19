import 'dart:io';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

class ImageSaver {
  static const platform = MethodChannel('com.surveilpro.app/media_scanner');

  // Share the image with other apps
  static Future<void> shareImage(File imageFile, {String? text}) async {
    try {
      // Create a copy with a meaningful name
      final tempDir = await getTemporaryDirectory();
      final fileName = 'enhanced_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedFile = await imageFile.copy('${tempDir.path}/$fileName');

      // Share the file
      await Share.shareXFiles(
        [XFile(savedFile.path)],
        text: text ?? 'Enhanced image from SurveilPro',
      );
    } catch (e) {
      print('Error sharing image: $e');
      rethrow;
    }
  }

  // Save directly to gallery - improved version
  static Future<Map<String, dynamic>> saveToGallery(File imageFile) async {
    try {
      // Use a more visible location - DCIM directory
      final directory = await getExternalStorageDirectory();
      if (directory == null) {
        return {'isSuccess': false, 'error': 'Could not access storage directory'};
      }

      // Navigate up to the external storage root (removing Android/data/package...)
      final String rootPath = directory.path.split('Android')[0];

      // Use DCIM directory which appears in most gallery apps
      final picturesDir = Directory('$rootPath/DCIM/SurveilPro');
      if (!await picturesDir.exists()) {
        await picturesDir.create(recursive: true);
      }

      // Copy file with timestamp
      final fileName = 'SurveilPro_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedPath = '${picturesDir.path}/$fileName';
      final savedFile = await imageFile.copy(savedPath);

      // Make the file visible in gallery (Android only)
      if (Platform.isAndroid) {
        try {
          await platform.invokeMethod('scanFile', {'path': savedFile.path});
        } catch (e) {
          print('Error scanning file: $e');
          // Continue even if scanning fails
        }
      }

      return {
        'isSuccess': true,
        'filePath': savedFile.path,
      };
    } catch (e) {
      print('Error saving image: $e');
      return {'isSuccess': false, 'error': e.toString()};
    }
  }
}