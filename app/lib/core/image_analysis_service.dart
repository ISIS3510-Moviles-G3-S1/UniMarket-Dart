import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

import '../models/analysis_result.dart';
import '../models/clothing_tag.dart';
import 'analysis_error.dart';
import 'clothing_category_mapper.dart';
import 'color_analyzer.dart';

abstract class ImageAnalysisService {
  Future<AnalysisResult> analyzeImage(XFile image);
  Future<AnalysisResult> analyzeBytes(Uint8List bytes, {String? fileName});
}

class MockClothingAnalysisService implements ImageAnalysisService {
  MockClothingAnalysisService({
    ColorAnalyzer? colorAnalyzer,
    ClothingCategoryMapper? categoryMapper,
  })  : _colorAnalyzer = colorAnalyzer ?? ColorAnalyzer(),
        _categoryMapper = categoryMapper ?? ClothingCategoryMapper();

  final ColorAnalyzer _colorAnalyzer;
  final ClothingCategoryMapper _categoryMapper;

  @override
  Future<AnalysisResult> analyzeImage(XFile image) async {
    final bytes = await image.readAsBytes();
    return analyzeBytes(bytes, fileName: image.name);
  }

  @override
  Future<AnalysisResult> analyzeBytes(Uint8List bytes, {String? fileName}) async {
    if (bytes.isEmpty) {
      throw const AnalysisError.invalidImage();
    }

    final stopwatch = Stopwatch()..start();

    try {
      final colors = await _colorAnalyzer.extractDominantColors(bytes, maxColors: 3);
      final primary = _pickPrimaryCategory(bytes, colors);
      final category = _categoryMapper.mapLabelToCategory(primary);
      final style = _categoryMapper.inferStyle(
        category: category,
        colors: colors,
        labelHint: primary,
      );
      final pattern = _categoryMapper.inferPattern(
            category: category,
            colors: colors,
            labelHint: primary,
          ) ??
          'Solid';

      final categoryConfidence = _confidenceForCategory(category);
      final colorConfidence = [0.92, 0.84, 0.76].take(colors.length).toList();
      final styleConfidence = 0.66;
      final patternConfidence = 0.58;

      final tags = <ClothingTag>[
        ClothingTag(
          id: generateClothingTagId(),
          name: category,
          confidence: categoryConfidence,
          category: TagCategory.category,
        ),
        for (var i = 0; i < colors.length; i++)
          ClothingTag(
            id: generateClothingTagId(),
            name: colors[i],
            confidence: colorConfidence[i],
            category: TagCategory.color,
          ),
        ClothingTag(
          id: generateClothingTagId(),
          name: style,
          confidence: styleConfidence,
          category: TagCategory.style,
        ),
        ClothingTag(
          id: generateClothingTagId(),
          name: pattern,
          confidence: patternConfidence,
          category: TagCategory.pattern,
        ),
      ];

      final confidence = _averageConfidence([
        categoryConfidence,
        ...colorConfidence,
        styleConfidence,
        patternConfidence,
      ]);

      stopwatch.stop();

      return AnalysisResult(
        category: category,
        colors: colors,
        style: style,
        pattern: pattern,
        confidence: confidence,
        processingTimeMs: stopwatch.elapsedMilliseconds,
        allTags: tags,
        timestamp: DateTime.now(),
      );
    } on AnalysisError {
      rethrow;
    } catch (e) {
      throw AnalysisError.processingFailed(e.toString());
    }
  }

  String _pickPrimaryCategory(Uint8List bytes, List<String> colors) {
    final signature = bytes.fold<int>(0, (sum, byte) => (sum + byte) & 0x7fffffff);
    final dominant = colors.isNotEmpty ? colors.first.toLowerCase() : 'blue';

    if (_containsAny(dominant, ['black', 'gray', 'grey', 'navy'])) {
      return ['Shirt', 'Jacket', 'Jeans', 'Sweater', 'Shoes'][signature % 5];
    }
    if (_containsAny(dominant, ['blue', 'teal', 'cyan'])) {
      return ['Shirt', 'Jeans', 'Sweater', 'Jacket', 'Shoes'][(signature + 1) % 5];
    }
    if (_containsAny(dominant, ['red', 'pink', 'orange', 'yellow'])) {
      return ['Shirt', 'Dress', 'Sweater', 'Jacket', 'Shoes'][(signature + 2) % 5];
    }
    if (_containsAny(dominant, ['white', 'beige', 'tan'])) {
      return ['Shirt', 'Pants', 'Dress', 'Jacket', 'Accessory'][(signature + 3) % 5];
    }

    return ['Shirt', 'Jeans', 'Sweater', 'Jacket', 'Shoes'][signature % 5];
  }

  double _confidenceForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'shirt':
        return 0.75;
      case 'pants':
        return 0.68;
      case 'dress':
        return 0.66;
      case 'jacket':
        return 0.62;
      case 'shoes':
        return 0.48;
      case 'accessory':
        return 0.55;
      case 'suit':
        return 0.61;
      default:
        return 0.50;
    }
  }

  double _averageConfidence(List<double> values) {
    if (values.isEmpty) return 0.0;
    final total = values.fold<double>(0, (sum, value) => sum + value);
    return (total / values.length).clamp(0.0, 1.0);
  }

  bool _containsAny(String value, List<String> needles) => needles.any(value.contains);
}