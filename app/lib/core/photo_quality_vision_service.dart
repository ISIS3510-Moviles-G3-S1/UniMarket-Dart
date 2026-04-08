import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class VisionPhotoQualityResult {
  final bool isBlurry;
  final bool isUnderexposed;
  final bool isOverexposed;
  final double blurLikelihood;
  final double exposureLikelihood;
  final String? error;

  VisionPhotoQualityResult({
    required this.isBlurry,
    required this.isUnderexposed,
    required this.isOverexposed,
    required this.blurLikelihood,
    required this.exposureLikelihood,
    this.error,
  });
}

class VisionPhotoQualityService {
  // Read from --dart-define=GOOGLE_CLOUD_VISION_API_KEY=... at build/run time.
  static const String _visionApiKeyFromEnv = String.fromEnvironment(
    'GOOGLE_CLOUD_VISION_API_KEY',
  );
  static const _visionUrl = 'https://vision.googleapis.com/v1/images:annotate';

  final String _apiKey;
  final http.Client _httpClient;

  VisionPhotoQualityService({String? apiKey, http.Client? httpClient})
      : _apiKey = (apiKey ?? _visionApiKeyFromEnv).trim(),
        _httpClient = httpClient ?? http.Client();

  /// Analyze photo and return feedback with AI suggestions (blur, brightness, etc)
  Future<Map<String, dynamic>> analyzePhotoWithFeedback(XFile image) async {
    final bytes = await image.readAsBytes();
    return analyzeBytesWithFeedback(bytes, fileName: image.name);
  }

  Future<Map<String, dynamic>> analyzeBytesWithFeedback(Uint8List bytes, {String? fileName}) async {
    if (bytes.isEmpty) {
      return {
        'error': 'Invalid image',
        'blur': null,
        'brightness': null,
        'suggestions': ['The image could not be processed.'],
      };
    }
    if (_apiKey.isEmpty) {
      return {
        'error': 'API key missing',
        'blur': null,
        'brightness': null,
        'suggestions': ['No API key provided. Please contact support.'],
      };
    }
    final payload = {
      'requests': [
        {
          'image': {'content': base64Encode(bytes)},
          'features': [
            {'type': 'IMAGE_PROPERTIES', 'maxResults': 1},
            {'type': 'LABEL_DETECTION', 'maxResults': 10},
          ],
        }
      ]
    };
    final uri = Uri.parse('$_visionUrl?key=$_apiKey');
    final response = await _httpClient.post(uri, body: jsonEncode(payload), headers: {'Content-Type': 'application/json'});
    if (response.statusCode != 200) {
      return {
        'error': 'Vision API error: ${response.statusCode}',
        'blur': null,
        'brightness': null,
        'suggestions': ['Vision API error. Try again later.'],
      };
    }
    final data = jsonDecode(response.body);
    try {
      final resp = data['responses'][0];
      // Blur detection
      final labels = resp['labelAnnotations'] as List<dynamic>? ?? [];
      bool isBlurry = false;
      double blurLikelihood = 0.0;
      double sharpScore = 0.0;
      double focusScore = 0.0;
      for (final label in labels) {
        final desc = (label['description'] as String).toLowerCase();
        final score = (label['score'] as num?)?.toDouble() ?? 0.0;
        if (desc.contains('blurry')) {
          isBlurry = true;
          blurLikelihood = score;
        }
        if (desc.contains('sharp')) {
          sharpScore = score;
        }
        if (desc.contains('focus')) {
          focusScore = score;
        }
      }
      if (!isBlurry && (sharpScore < 0.5 && focusScore < 0.5)) {
        isBlurry = true;
        blurLikelihood = 0.2;
      }
      // Brightness
      final props = resp['imagePropertiesAnnotation']?['dominantColors']?['colors'] as List<dynamic>? ?? [];
      double avgBrightness = 0.0;
      if (props.isNotEmpty) {
        for (final c in props) {
          avgBrightness += (c['color']['red'] as num) * 0.299 + (c['color']['green'] as num) * 0.587 + (c['color']['blue'] as num) * 0.114;
        }
        avgBrightness /= props.length;
      }
      bool isUnderexposed = avgBrightness < 60;
      bool isOverexposed = avgBrightness > 200;
      double exposureLikelihood = avgBrightness / 255.0;
      // Suggestions
      final suggestions = <String>[];
      if (isBlurry || blurLikelihood > 0.15) {
        suggestions.add('Try holding the camera steady or cleaning the lens.');
      } else if (blurLikelihood > 0.08) {
        suggestions.add('Photo may be slightly blurry.');
      }
      if (isUnderexposed) {
        suggestions.add('Try taking the photo in better lighting.');
      }
      if (isOverexposed) {
        suggestions.add('Avoid too much light or glare.');
      }
      if (suggestions.isEmpty) {
        suggestions.add('Try changing the lighting or make sure the photo is clear.');
      }
      return {
        'blur': {
          'isBlurry': isBlurry,
          'blurLikelihood': blurLikelihood,
        },
        'brightness': {
          'isUnderexposed': isUnderexposed,
          'isOverexposed': isOverexposed,
          'exposureLikelihood': exposureLikelihood,
        },
        'suggestions': suggestions,
        'error': null,
      };
    } catch (e) {
      return {
        'error': 'Parsing error: $e',
        'blur': null,
        'brightness': null,
        'suggestions': ['Could not analyze the image.'],
      };
    }
  }

  Future<VisionPhotoQualityResult> analyzePhoto(XFile image) async {
    final bytes = await image.readAsBytes();
    return analyzeBytes(bytes, fileName: image.name);
  }

  Future<VisionPhotoQualityResult> analyzeBytes(Uint8List bytes, {String? fileName}) async {
    if (bytes.isEmpty) {
      return VisionPhotoQualityResult(
        isBlurry: false,
        isUnderexposed: false,
        isOverexposed: false,
        blurLikelihood: 0.0,
        exposureLikelihood: 0.0,
        error: 'Invalid image',
      );
    }
    if (_apiKey.isEmpty) {
      return VisionPhotoQualityResult(
        isBlurry: false,
        isUnderexposed: false,
        isOverexposed: false,
        blurLikelihood: 0.0,
        exposureLikelihood: 0.0,
        error: 'API key missing',
      );
    }
    final payload = {
      'requests': [
        {
          'image': {'content': base64Encode(bytes)},
          'features': [
            {'type': 'IMAGE_PROPERTIES', 'maxResults': 1},
            {'type': 'LABEL_DETECTION', 'maxResults': 10},
          ],
        }
      ]
    };
    final uri = Uri.parse('$_visionUrl?key=$_apiKey');
    final response = await _httpClient.post(uri, body: jsonEncode(payload), headers: {'Content-Type': 'application/json'});
    if (response.statusCode != 200) {
      return VisionPhotoQualityResult(
        isBlurry: false,
        isUnderexposed: false,
        isOverexposed: false,
        blurLikelihood: 0.0,
        exposureLikelihood: 0.0,
        error: 'Vision API error: ${response.statusCode}',
      );
    }
    final data = jsonDecode(response.body);
    try {
      final resp = data['responses'][0];
      // Check for blur using LABEL_DETECTION (improved sensitivity)
      final labels = resp['labelAnnotations'] as List<dynamic>? ?? [];
      bool isBlurry = false;
      double blurLikelihood = 0.0;
      double sharpScore = 0.0;
      double focusScore = 0.0;
      for (final label in labels) {
        final desc = (label['description'] as String).toLowerCase();
        final score = (label['score'] as num?)?.toDouble() ?? 0.0;
        if (desc.contains('blurry')) {
          isBlurry = true;
          blurLikelihood = score;
        }
        if (desc.contains('sharp')) {
          sharpScore = score;
        }
        if (desc.contains('focus')) {
          focusScore = score;
        }
      }
      // If not labeled blurry, but sharp/focus confidence is low, treat as blurry
      if (!isBlurry && (sharpScore < 0.5 && focusScore < 0.5)) {
        isBlurry = true;
        blurLikelihood = 0.2; // Assign a moderate blur likelihood
      }
      // Check for exposure using IMAGE_PROPERTIES
      final props = resp['imagePropertiesAnnotation']?['dominantColors']?['colors'] as List<dynamic>? ?? [];
      double avgBrightness = 0.0;
      if (props.isNotEmpty) {
        for (final c in props) {
          avgBrightness += (c['color']['red'] as num) * 0.299 + (c['color']['green'] as num) * 0.587 + (c['color']['blue'] as num) * 0.114;
        }
        avgBrightness /= props.length;
      }
      // Heuristic: <60 underexposed, >200 overexposed
      bool isUnderexposed = avgBrightness < 60;
      bool isOverexposed = avgBrightness > 200;
      double exposureLikelihood = avgBrightness / 255.0;
      return VisionPhotoQualityResult(
        isBlurry: isBlurry,
        isUnderexposed: isUnderexposed,
        isOverexposed: isOverexposed,
        blurLikelihood: blurLikelihood,
        exposureLikelihood: exposureLikelihood,
        error: null,
      );
    } catch (e) {
      return VisionPhotoQualityResult(
        isBlurry: false,
        isUnderexposed: false,
        isOverexposed: false,
        blurLikelihood: 0.0,
        exposureLikelihood: 0.0,
        error: 'Parsing error: $e',
      );
    }
  }
}
