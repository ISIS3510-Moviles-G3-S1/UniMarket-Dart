import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/api_config.dart';
import '../models/ai_outfit_analysis.dart';
import '../models/listing.dart';
import '../data/ai_outfit_local_storage_service.dart';

class AIStylistServiceException implements Exception {
  const AIStylistServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PreparedOutfitImage {
  final String sourcePath;
  final String fileName;
  final String cacheHash;
  final List<String> dominantColors;
  final Uint8List compressedBytes;
  final Uint8List thumbnailBytes;

  const PreparedOutfitImage({
    required this.sourcePath,
    required this.fileName,
    required this.cacheHash,
    required this.dominantColors,
    required this.compressedBytes,
    required this.thumbnailBytes,
  });
}

class AIStylistService {
  AIStylistService({
    AIOutfitLocalStorageService? storage,
    http.Client? client,
    FirebaseFirestore? firestore,
  })  : _storage = storage ?? AIOutfitLocalStorageService(),
        _client = client ?? http.Client(),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AIOutfitLocalStorageService _storage;
  final http.Client _client;
  final FirebaseFirestore _firestore;

  static const _systemPrompt =
      'You are UniMarket\'s AI Outfit Stylist. Analyze these clothing images for outfit styling only. Do not create a marketplace listing. Return JSON with categories, dominantColors, style, aesthetic, outfitAdvice, missingItems, and marketplaceTags.';

  Future<AIOutfitAnalysis> analyzeOutfit(
    List<XFile> images, {
    bool allowCache = true,
    bool allowOfflinePending = true,
  }) async {
    if (images.isEmpty) {
      throw const AIStylistServiceException('Please select at least one clothing image.');
    }
    if (images.length > 3) {
      throw const AIStylistServiceException('You can analyze up to 3 images at a time.');
    }

    // Future.wait keeps each selected image processing in parallel instead of serializing the work.
    final preparedImages = await Future.wait(images.map(_prepareImage));
    final cacheKey = _buildCacheKey(preparedImages);

    if (allowCache) {
      final cached = await _storage.getByCacheKey(cacheKey);
      if (cached != null) {
        return cached.copyWith(fromCache: true, errorMessage: null);
      }
    }

    final isOnline = await _isOnline();
    if (!isOnline && allowOfflinePending) {
      // Ensure thumbnails and prepared files are persisted so the pending analysis
      // can be reprocessed later even if original gallery files are removed.
      final thumbnailPaths = await _writeThumbnails(preparedImages);

      final pending = _buildFallbackAnalysis(preparedImages, cacheKey: cacheKey, thumbnailPaths: thumbnailPaths).copyWith(
        syncStatus: AIOutfitSyncStatus.pending,
        errorMessage: 'Pending analysis - will sync when internet returns',
      );
      await _storage.saveAnalysis(pending);
      return pending;
    }

    try {
      final result = await _analyzeWithAi(preparedImages, cacheKey: cacheKey);
      await _storage.saveAnalysis(result);
      return result;
    } catch (error) {
      final fallback = _buildFallbackAnalysis(preparedImages, cacheKey: cacheKey).copyWith(
        syncStatus: AIOutfitSyncStatus.failed,
        errorMessage: error.toString(),
      );
      await _storage.saveAnalysis(fallback);
      return fallback;
    }
  }

  Future<AIOutfitAnalysis> reanalyzePending(AIOutfitAnalysis pending) async {
    final images = pending.imagePaths.map((path) => XFile(path)).toList(growable: false);
    return analyzeOutfit(
      images,
      allowCache: false,
      allowOfflinePending: false,
    );
  }

  Future<List<Listing>> getRecommendedListings(AIOutfitAnalysis analysis, {int limit = 6}) async {
    final tags = <String>{
      ...analysis.marketplaceTags,
      ...analysis.categories,
      ...analysis.dominantColors,
    }.where((tag) => tag.trim().isNotEmpty).map((tag) => tag.trim().toLowerCase()).toList();

    if (tags.isEmpty) return const <Listing>[];

    final queryTags = tags.take(10).toList(growable: false);
    final snapshot = await _firestore.collection('listings').where('tags', arrayContainsAny: queryTags).limit(limit * 2).get();
    final listings = snapshot.docs.map(Listing.fromFirestore).where((listing) {
      final listingTags = listing.tags.map((tag) => tag.toLowerCase()).toList();
      return listingTags.any(tags.contains) ||
          listing.title.toLowerCase().containsAny(tags) ||
          listing.description.toLowerCase().containsAny(tags);
    }).take(limit).toList(growable: false);

    return listings;
  }

  Future<AIOutfitAnalysis> _analyzeWithAi(
    List<PreparedOutfitImage> preparedImages, {
    required String cacheKey,
  }) async {
    if (APIConfig.openRouterApiKey.trim().isEmpty) {
      throw const AIStylistServiceException('AI configuration is missing.');
    }

    final userContent = <Map<String, dynamic>>[
      {
        'type': 'text',
        'text': 'Analyze these clothing images for outfit styling only. Do not create a marketplace listing. Return JSON with categories, dominantColors, style, aesthetic, outfitAdvice, missingItems, and marketplaceTags.',
      },
      for (final image in preparedImages)
        {
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,${base64Encode(image.compressedBytes)}',
          },
        },
    ];

    final response = await _client
        .post(
          Uri.parse(APIConfig.openRouterUrl),
          headers: {
            'Authorization': 'Bearer ${APIConfig.openRouterApiKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': APIConfig.openRouterModel,
            'messages': [
              {'role': 'system', 'content': _systemPrompt},
              {'role': 'user', 'content': userContent},
            ],
            'response_format': {
              'type': 'json_object',
            },
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AIStylistServiceException('AI request failed with status ${response.statusCode}.');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const AIStylistServiceException('AI returned an invalid response.');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const AIStylistServiceException('AI returned no analysis.');
    }

    final message = choices.first is Map ? Map<String, dynamic>.from(choices.first as Map) : null;
    final content = message?['message'] is Map ? (message!['message'] as Map)['content'] : null;
    if (content is! String || content.trim().isEmpty) {
      throw const AIStylistServiceException('AI returned empty content.');
    }

    final payload = _extractJsonObject(content);
    final analysis = _analysisFromJson(
      payload,
      cacheKey: cacheKey,
      imagePaths: preparedImages.map((image) => image.sourcePath).toList(growable: false),
      thumbnailPaths: await _writeThumbnails(preparedImages),
    );

    return analysis.copyWith(fromCache: false, syncStatus: AIOutfitSyncStatus.synced);
  }

  Future<PreparedOutfitImage> _prepareImage(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) {
      throw const AIStylistServiceException('One of the selected images is empty.');
    }

    // compute() keeps the CPU-heavy compression and color extraction off the UI isolate.
    final prepared = await compute(_prepareOutfitImageWorker, {
      'path': image.path,
      'name': image.name,
      'bytes': bytes,
    });

    // Persist the compressed image so it remains available for future reanalysis
    // even if the original gallery file is removed.
    final cacheHash = prepared['cacheHash']?.toString() ?? sha256.convert(bytes).toString();
    final compressed = List<int>.from(prepared['compressedBytes'] as List? ?? const []);

    final supportDir = await getApplicationSupportDirectory();
    final imagesDir = Directory(p.join(supportDir.path, 'ai_outfit_images'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final storedPath = p.join(imagesDir.path, '${cacheHash}.jpg');
    final storedFile = File(storedPath);
    if (!await storedFile.exists()) {
      await storedFile.writeAsBytes(compressed, flush: true);
    }

    return PreparedOutfitImage(
      sourcePath: storedPath,
      fileName: prepared['fileName']?.toString() ?? image.name,
      cacheHash: cacheHash,
      dominantColors: (prepared['dominantColors'] as List? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.trim().isNotEmpty)
          .toList(growable: false),
      compressedBytes: Uint8List.fromList(compressed),
      thumbnailBytes: Uint8List.fromList(List<int>.from(prepared['thumbnailBytes'] as List? ?? const [])),
    );
  }

  Future<List<String>> _writeThumbnails(List<PreparedOutfitImage> preparedImages) async {
    final directory = await getApplicationSupportDirectory();
    final thumbnailDir = Directory(p.join(directory.path, 'ai_outfit_thumbs'));
    if (!await thumbnailDir.exists()) {
      await thumbnailDir.create(recursive: true);
    }

    final paths = <String>[];
    for (final image in preparedImages) {
      final filePath = p.join(thumbnailDir.path, '${image.cacheHash}.jpg');
      final file = File(filePath);
      if (!await file.exists()) {
        await file.writeAsBytes(image.thumbnailBytes, flush: true);
      }
      paths.add(filePath);
    }
    return paths;
  }

  Future<bool> _isOnline() async {
    final connectivityResults = await Connectivity().checkConnectivity();
    return connectivityResults.isNotEmpty && !connectivityResults.contains(ConnectivityResult.none);
  }

  String _buildCacheKey(List<PreparedOutfitImage> preparedImages) {
    final hashes = preparedImages.map((image) => image.cacheHash).toList()..sort();
    return sha256.convert(utf8.encode(hashes.join('|'))).toString();
  }

  AIOutfitAnalysis _buildFallbackAnalysis(
    List<PreparedOutfitImage> preparedImages, {
    required String cacheKey,
    List<String> thumbnailPaths = const [],
  }) {
    final categories = preparedImages
        .map((image) => _guessCategory(image.fileName, image.dominantColors))
        .where((category) => category.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    final dominantColors = preparedImages
        .expand((image) => image.dominantColors)
        .where((color) => color.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);

    final style = _guessStyle(categories: categories, colors: dominantColors);
    final aesthetic = _guessAesthetic(categories: categories, colors: dominantColors);
    final missingItems = _guessMissingItems(categories);
    final advice = _buildAdvice(categories, dominantColors, style, aesthetic, missingItems);
    final marketplaceTags = _buildMarketplaceTags(categories, dominantColors, style, aesthetic);

    return AIOutfitAnalysis(
      id: 'ai_outfit_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      imagePaths: preparedImages.map((image) => image.sourcePath).toList(growable: false),
      thumbnailPaths: thumbnailPaths,
      categories: categories.isEmpty ? const ['Outfit'] : categories,
      dominantColors: dominantColors.isEmpty ? const ['Neutral'] : dominantColors,
      style: style,
      aesthetic: aesthetic,
      outfitAdvice: advice,
      missingItems: missingItems,
      marketplaceTags: marketplaceTags,
      fromCache: false,
      syncStatus: AIOutfitSyncStatus.pending,
      cacheKey: cacheKey,
    );
  }

  AIOutfitAnalysis _analysisFromJson(
    Map<String, dynamic> json, {
    required String cacheKey,
    required List<String> imagePaths,
    required List<String> thumbnailPaths,
  }) {
    List<String> asStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).where((item) => item.trim().isNotEmpty).toList();
      }
      if (value is String && value.trim().isNotEmpty) {
        return [value];
      }
      return const <String>[];
    }

    return AIOutfitAnalysis(
      id: 'ai_outfit_${DateTime.now().microsecondsSinceEpoch}',
      createdAt: DateTime.now(),
      imagePaths: imagePaths,
      thumbnailPaths: thumbnailPaths,
      categories: asStringList(json['categories']),
      dominantColors: asStringList(json['dominantColors']),
      style: (json['style'] ?? '').toString(),
      aesthetic: (json['aesthetic'] ?? '').toString(),
      outfitAdvice: (json['outfitAdvice'] ?? '').toString(),
      missingItems: asStringList(json['missingItems']),
      marketplaceTags: asStringList(json['marketplaceTags']),
      fromCache: false,
      syncStatus: AIOutfitSyncStatus.synced,
      cacheKey: cacheKey,
    );
  }

  Map<String, dynamic> _extractJsonObject(String content) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    }

    final firstBrace = trimmed.indexOf('{');
    final lastBrace = trimmed.lastIndexOf('}');
    if (firstBrace >= 0 && lastBrace > firstBrace) {
      final snippet = trimmed.substring(firstBrace, lastBrace + 1);
      final parsed = jsonDecode(snippet);
      if (parsed is Map<String, dynamic>) return parsed;
      if (parsed is Map) return Map<String, dynamic>.from(parsed);
    }

    throw const AIStylistServiceException('Could not parse the AI response JSON.');
  }

  String _guessCategory(String fileName, List<String> dominantColors) {
    final name = fileName.toLowerCase();
    if (name.contains('shirt') || name.contains('blouse') || name.contains('top') || name.contains('tee')) {
      return 'Top';
    }
    if (name.contains('pant') || name.contains('jean') || name.contains('trouser') || name.contains('short')) {
      return 'Bottom';
    }
    if (name.contains('dress') || name.contains('skirt')) {
      return 'Dress';
    }
    if (name.contains('shoe') || name.contains('sneaker') || name.contains('boot')) {
      return 'Shoes';
    }
    if (name.contains('jacket') || name.contains('coat') || name.contains('blazer')) {
      return 'Outerwear';
    }
    if (dominantColors.any((color) => const {'black', 'white', 'gray', 'grey', 'beige', 'navy'}.contains(color.toLowerCase()))) {
      return 'Wardrobe Piece';
    }
    return 'Clothing';
  }

  String _guessStyle({required List<String> categories, required List<String> colors}) {
    final lowerColors = colors.map((color) => color.toLowerCase()).toSet();
    if (lowerColors.any((color) => const {'black', 'white', 'gray', 'grey', 'beige', 'navy'}.contains(color))) {
      return 'Minimalist';
    }
    if (categories.any((category) => category.toLowerCase().contains('outerwear'))) {
      return 'Layered Casual';
    }
    if (categories.any((category) => category.toLowerCase().contains('dress'))) {
      return 'Polished';
    }
    return 'Casual';
  }

  String _guessAesthetic({required List<String> categories, required List<String> colors}) {
    if (categories.length >= 2) return 'Balanced everyday outfit';
    if (colors.any((color) => const {'black', 'white'}.contains(color.toLowerCase()))) {
      return 'Clean monochrome';
    }
    return 'Campus-ready style';
  }

  List<String> _guessMissingItems(List<String> categories) {
    final lower = categories.map((category) => category.toLowerCase()).toList();
    final missing = <String>[];
    if (!lower.any((value) => value.contains('top'))) missing.add('Top');
    if (!lower.any((value) => value.contains('bottom') || value.contains('pant') || value.contains('jean') || value.contains('skirt'))) {
      missing.add('Bottom');
    }
    if (!lower.any((value) => value.contains('shoe'))) missing.add('Shoes');
    return missing;
  }

  String _buildAdvice(List<String> categories, List<String> colors, String style, String aesthetic, List<String> missingItems) {
    if (missingItems.isNotEmpty) {
      return 'Add ${missingItems.join(', ').toLowerCase()} to complete the outfit. The current pieces lean $style with a $aesthetic feel.';
    }
    final colorNote = colors.isEmpty ? 'the current palette' : colors.take(2).join(' and ');
    return 'This set works best as a $style look. Keep ${colorNote.toLowerCase()} together and add a light accessory or layer for balance.';
  }

  List<String> _buildMarketplaceTags(List<String> categories, List<String> colors, String style, String aesthetic) {
    final tags = <String>{
      ...categories,
      ...colors,
      style,
      aesthetic,
    };
    return tags.map((tag) => tag.trim().toLowerCase()).where((tag) => tag.isNotEmpty).toList(growable: false);
  }
}

extension _StringContainsAny on String {
  bool containsAny(Iterable<String> values) {
    for (final value in values) {
      if (contains(value)) return true;
    }
    return false;
  }
}

@pragma('vm:entry-point')
Map<String, dynamic> _prepareOutfitImageWorker(Map<String, dynamic> payload) {
  final bytes = Uint8List.fromList(List<int>.from(payload['bytes'] as List));
  final image = img.decodeImage(bytes);
  if (image == null) {
    throw ArgumentError('Unable to decode selected image.');
  }

  final resized = image.width > 1600 ? img.copyResize(image, width: 1600) : image;
  final thumbnail = resized.width > 480 ? img.copyResize(resized, width: 480) : resized;
  final compressed = img.encodeJpg(resized, quality: 82);
  final thumbnailBytes = img.encodeJpg(thumbnail, quality: 76);
  final dominantColors = _extractDominantColorNames(resized, maxColors: 3);
  final cacheHash = sha256.convert(compressed).toString();

  return {
    'sourcePath': payload['path']?.toString() ?? '',
    'fileName': payload['name']?.toString() ?? '',
    'compressedBytes': compressed,
    'thumbnailBytes': thumbnailBytes,
    'dominantColors': dominantColors,
    'cacheHash': cacheHash,
  };
}

List<String> _extractDominantColorNames(img.Image image, {int maxColors = 3}) {
  final buckets = <int, int>{};
  final stepX = (image.width ~/ 40).clamp(1, 20);
  final stepY = (image.height ~/ 40).clamp(1, 20);

  for (int y = 0; y < image.height; y += stepY) {
    for (int x = 0; x < image.width; x += stepX) {
      final pixel = image.getPixel(x, y);
      final red = (pixel >> 16) & 0xFF;
      final green = (pixel >> 8) & 0xFF;
      final blue = pixel & 0xFF;
      final bucket = ((red >> 3) << 10) | ((green >> 3) << 5) | (blue >> 3);
      buckets[bucket] = (buckets[bucket] ?? 0) + 1;
    }
  }

  final sortedBuckets = buckets.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  final colors = <String>[];
  for (final entry in sortedBuckets.take(maxColors * 2)) {
    final red = ((entry.key >> 10) & 0x1F) * 8 + 4;
    final green = ((entry.key >> 5) & 0x1F) * 8 + 4;
    final blue = (entry.key & 0x1F) * 8 + 4;
    final name = _nearestNamedColor(red, green, blue);
    if (!colors.contains(name)) {
      colors.add(name);
    }
    if (colors.length >= maxColors) break;
  }

  return colors.isEmpty ? const ['Neutral'] : colors;
}

String _nearestNamedColor(int red, int green, int blue) {
  const references = <String, List<int>>{
    'Black': [0, 0, 0],
    'White': [255, 255, 255],
    'Gray': [128, 128, 128],
    'Navy': [29, 53, 87],
    'Blue': [33, 150, 243],
    'Teal': [0, 128, 128],
    'Green': [76, 175, 80],
    'Yellow': [255, 235, 59],
    'Orange': [255, 152, 0],
    'Red': [244, 67, 54],
    'Pink': [233, 30, 99],
    'Purple': [156, 39, 176],
    'Brown': [141, 110, 99],
    'Beige': [245, 230, 196],
    'Tan': [210, 180, 140],
  };

  String bestName = 'Blue';
  double bestDistance = double.infinity;

  for (final entry in references.entries) {
    final candidate = entry.value;
    final dr = red - candidate[0];
    final dg = green - candidate[1];
    final db = blue - candidate[2];
    final distance = (dr * dr + dg * dg + db * db).toDouble();
    if (distance < bestDistance) {
      bestDistance = distance;
      bestName = entry.key;
    }
  }

  return bestName;
}