import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

class IdDetectionService {
  // You'll need to get your own API key from Google Cloud Vision API
  static const String _googleVisionApiKey = 'YOUR_GOOGLE_VISION_API_KEY';
  static const String _googleVisionEndpoint =
      'https://vision.googleapis.com/v1/images:annotate';

  /// Detects the type of ID from an image using OCR
  static Future<IdDetectionResult> detectIdType(XFile imageFile) async {
    try {
      // Convert image to base64
      String base64Image;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);
      } else {
        final bytes = await File(imageFile.path).readAsBytes();
        base64Image = base64Encode(bytes);
      }

      // Prepare the request for Google Vision API
      final requestBody = {
        'requests': [
          {
            'image': {'content': base64Image},
            'features': [
              {'type': 'TEXT_DETECTION', 'maxResults': 10}
            ]
          }
        ]
      };

      // Make API call to Google Vision
      final response = await http.post(
        Uri.parse('$_googleVisionEndpoint?key=$_googleVisionApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final textAnnotations = responseData['responses'][0]['textAnnotations'];

        if (textAnnotations != null && textAnnotations.isNotEmpty) {
          final detectedText =
              textAnnotations[0]['description'].toString().toUpperCase();
          return _analyzeDetectedText(detectedText);
        }
      }

      return IdDetectionResult(
        detectedIdType: 'Unknown',
        confidence: 0.0,
        rawText: '',
        isSuccess: false,
      );
    } catch (e) {
      debugPrint('Error detecting ID type: $e');
      return IdDetectionResult(
        detectedIdType: 'Error',
        confidence: 0.0,
        rawText: '',
        isSuccess: false,
        error: e.toString(),
      );
    }
  }

  /// Alternative method using pattern matching for offline detection
  static IdDetectionResult detectIdTypeOffline(String extractedText) {
    return _analyzeDetectedText(extractedText.toUpperCase());
  }

  /// Analyzes the detected text to determine ID type
  static IdDetectionResult _analyzeDetectedText(String text) {
    final patterns = {
      'National ID (PhilID)': [
        'PHILIPPINE IDENTIFICATION',
        'PHILSYS',
        'REPUBLIC OF THE PHILIPPINES',
        'PHILIPPINE STATISTICS AUTHORITY'
      ],
      'SSS ID': ['SOCIAL SECURITY SYSTEM', 'SSS', 'SS NO', 'SOCIAL SECURITY'],
      'GSIS ID': [
        'GOVERNMENT SERVICE INSURANCE SYSTEM',
        'GSIS',
        'GOVERNMENT SERVICE',
        'INSURANCE SYSTEM'
      ],
      'TIN ID': [
        'BUREAU OF INTERNAL REVENUE',
        'BIR',
        'TAXPAYER IDENTIFICATION',
        'TAX IDENTIFICATION'
      ],
      'Postal ID': [
        'PHILIPPINE POSTAL CORPORATION',
        'POSTAL ID',
        'PHLPOST',
        'PHILIPPINE POSTAL'
      ],
      'Voter\'s ID': [
        'COMMISSION ON ELECTIONS',
        'COMELEC',
        'VOTER\'S',
        'VOTER IDENTIFICATION'
      ],
      'PWD ID': [
        'PERSON WITH DISABILITY',
        'PWD',
        'DEPARTMENT OF SOCIAL WELFARE',
        'DSWD'
      ],
      'Senior Citizen ID': [
        'SENIOR CITIZEN',
        'SENIOR',
        'OFFICE FOR SENIOR CITIZENS'
      ],
      'PRC ID': [
        'PROFESSIONAL REGULATION COMMISSION',
        'PRC',
        'PROFESSIONAL',
        'LICENSE'
      ],
      'PhilHealth ID': [
        'PHILIPPINE HEALTH INSURANCE',
        'PHILHEALTH',
        'HEALTH INSURANCE',
        'PHIC'
      ],
      'Driver\'s License': [
        'DRIVER\'S LICENSE',
        'DRIVING LICENSE',
        'LAND TRANSPORTATION OFFICE',
        'LTO',
        'PROFESSIONAL DRIVER',
        'NON-PROFESSIONAL DRIVER'
      ],
      'Passport': [
        'PASSPORT',
        'REPUBLIC OF THE PHILIPPINES',
        'DEPARTMENT OF FOREIGN AFFAIRS',
        'DFA'
      ],
      'UMID': ['UNIFIED MULTI-PURPOSE ID', 'UMID', 'UNIFIED MULTIPURPOSE']
    };

    double maxConfidence = 0.0;
    String detectedType = 'Unknown';

    for (final entry in patterns.entries) {
      double confidence = 0.0;
      int matches = 0;

      for (final pattern in entry.value) {
        if (text.contains(pattern)) {
          matches++;
        }
      }

      if (matches > 0) {
        confidence = matches / entry.value.length;
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          detectedType = entry.key;
        }
      }
    }

    return IdDetectionResult(
      detectedIdType: detectedType,
      confidence: maxConfidence,
      rawText: text,
      isSuccess: maxConfidence > 0.3, // Consider successful if confidence > 30%
    );
  }

  /// Validates if the detected ID matches the selected ID type
  static ValidationResult validateIdMatch(
      String selectedId, String detectedId) {
    if (selectedId == 'Select Valid ID' ||
        detectedId == 'Unknown' ||
        detectedId == 'Error') {
      return ValidationResult(
        isMatch: false,
        confidence: 0.0,
        message: 'Unable to validate ID type',
      );
    }

    // Direct match
    if (selectedId == detectedId) {
      return ValidationResult(
        isMatch: true,
        confidence: 1.0,
        message: 'ID type matches perfectly',
      );
    }

    // Check for similar IDs (partial matches)
    final similarIds = {
      'ID Card': ['Company ID', 'School ID', 'Barangay ID'],
      'National ID (PhilID)': ['PhilID'],
      'Driver\'s License': ['Driving License'],
    };

    for (final entry in similarIds.entries) {
      if (entry.key == selectedId && entry.value.contains(detectedId)) {
        return ValidationResult(
          isMatch: true,
          confidence: 0.8,
          message: 'ID type is similar to selected type',
        );
      }
    }

    return ValidationResult(
      isMatch: false,
      confidence: 0.0,
      message:
          'Selected ID type ($selectedId) does not match detected ID type ($detectedId)',
    );
  }
}

class IdDetectionResult {
  final String detectedIdType;
  final double confidence;
  final String rawText;
  final bool isSuccess;
  final String? error;

  IdDetectionResult({
    required this.detectedIdType,
    required this.confidence,
    required this.rawText,
    required this.isSuccess,
    this.error,
  });
}

class ValidationResult {
  final bool isMatch;
  final double confidence;
  final String message;

  ValidationResult({
    required this.isMatch,
    required this.confidence,
    required this.message,
  });
}
