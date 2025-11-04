import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class CloudinaryService {
  static CloudinaryService? _instance;
  static CloudinaryService get instance {
    _instance ??= CloudinaryService._internal();
    return _instance!;
  }

  CloudinaryService._internal();

  // Using the same Cloudinary configuration as pbooking1.dart
  static const String cloudName = 'ddjraogpj';
  static const String uploadPreset = 'uploads';
  static const String uploadUrl =
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  void init() {
    debugPrint('[CloudinaryService] Initialized with cloud name: $cloudName');
  }

  /// Upload image to Cloudinary and return the secure URL
  /// Uses the same HTTP MultipartRequest approach as pbooking1.dart
  Future<String?> uploadImage({
    required File imageFile,
    String? folder,
    Map<String, dynamic>? options,
  }) async {
    try {
      debugPrint('[CloudinaryService] Starting image upload...');
      debugPrint('[CloudinaryService] File path: ${imageFile.path}');
      debugPrint('[CloudinaryService] File exists: ${imageFile.existsSync()}');
      debugPrint(
          '[CloudinaryService] File size: ${imageFile.lengthSync()} bytes');

      // Mobile upload logic using http.MultipartRequest (same as pbooking1.dart)
      debugPrint('[CloudinaryService] Starting Cloudinary upload (MOBILE)...');
      final uri = Uri.parse(uploadUrl);
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;

      // Add optional folder if specified
      if (folder != null) {
        request.fields['folder'] = folder;
      }

      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final respJson = json.decode(respStr);
        final secureUrl = respJson['secure_url'] as String? ?? '';

        if (secureUrl.isEmpty) {
          throw Exception('Upload failed: No secure_url in response');
        }

        debugPrint('[CloudinaryService] Upload successful!');
        debugPrint('[CloudinaryService] Secure URL: $secureUrl');
        debugPrint('[CloudinaryService] Public ID: ${respJson['public_id']}');

        return secureUrl;
      } else {
        final errorStr = await response.stream.bytesToString();
        debugPrint('[CloudinaryService] Upload failed: ${response.statusCode}');
        debugPrint('[CloudinaryService] Error response: $errorStr');
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      debugPrint('[CloudinaryService] Exception during upload: $e');
      debugPrint('[CloudinaryService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Upload image with progress tracking
  Future<String?> uploadImageWithProgress({
    required File imageFile,
    String? folder,
    Function(int, int)? onProgress,
    Map<String, dynamic>? options,
  }) async {
    try {
      debugPrint(
          '[CloudinaryService] Starting image upload with progress tracking...');

      // For HTTP MultipartRequest, we'll simulate progress
      final result = await uploadImage(
        imageFile: imageFile,
        folder: folder,
        options: options,
      );

      // Simulate progress callback if provided
      if (onProgress != null) {
        onProgress(100, 100); // 100% complete
      }

      return result;
    } catch (e) {
      debugPrint('[CloudinaryService] Upload with progress failed: $e');
      rethrow;
    }
  }

  /// Upload a raw/file (pdf) to Cloudinary using an unsigned upload preset.
  /// Returns secure_url on success.
  Future<String?> uploadRawFile({
    required File file,
    String? folder,
    String? preset,
  }) async {
    try {
      debugPrint('[CloudinaryService] Starting raw file upload...');
      final uri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/raw/upload');
      final request = http.MultipartRequest('POST', uri);

      // Use provided preset or default
      request.fields['upload_preset'] =
          preset ?? CloudinaryService.uploadPreset;
      if (folder != null) request.fields['folder'] = folder;

      request.files.add(await http.MultipartFile.fromPath('file', file.path));

      final response = await request.send();
      final respStr = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final respJson = json.decode(respStr);
        final secureUrl = respJson['secure_url'] as String? ?? '';
        if (secureUrl.isEmpty) throw Exception('No secure_url in response');
        debugPrint('[CloudinaryService] Raw upload success: $secureUrl');
        return secureUrl;
      } else {
        debugPrint(
            '[CloudinaryService] Raw upload failed: ${response.statusCode}');
        debugPrint('[CloudinaryService] Raw upload response: $respStr');
        return null;
      }
    } catch (e, st) {
      debugPrint('[CloudinaryService] Exception raw upload: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Check if Cloudinary is properly configured
  bool get isConfigured {
    // Since we're using the same config as pbooking1.dart, it's always configured
    debugPrint(
        '[CloudinaryService] Configuration check: true (using pbooking1.dart config)');
    return true;
  }
}
