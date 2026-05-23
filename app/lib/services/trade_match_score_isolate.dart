import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/trade_match_score.dart';

class TradeMatchScoreIsolate {
  /// Top-level or static function representing the CPU-bound entry point
  static Future<Map<String, TradeMatchScore>> calculateScoresBulk({
    required String desiredId,
    required double desiredPrice,
    required List<String> desiredTags,
    required List<Map<String, dynamic>> offeredListings, // List of {'id': String, 'price': double, 'tags': List<String>}
  }) async {
    final payload = {
      'desiredPrice': desiredPrice,
      'desiredTags': desiredTags,
      'offeredListings': offeredListings,
    };
    final serializedResult = await compute(_calculateFairnessScores, payload);
    return serializedResult.map((key, val) => MapEntry(key, TradeMatchScore.fromJson(val)));
  }
}

Map<String, Map<String, dynamic>> _calculateFairnessScores(Map<String, dynamic> payload) {
  final double desiredPrice = (payload['desiredPrice'] as num).toDouble();
  final List<String> desiredTags = List<String>.from(payload['desiredTags'] ?? []);
  final List<dynamic> rawOffered = payload['offeredListings'] ?? [];

  final Map<String, Map<String, dynamic>> results = {};

  final Set<String> setA = desiredTags.map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toSet();

  for (final item in rawOffered) {
    final String id = item['id'] as String;
    final double offeredPrice = (item['price'] as num).toDouble();
    final List<String> offeredTags = List<String>.from(item['tags'] ?? []);

    // 1. Price fairness score (0 to 100)
    double priceFairness = 100.0;
    if (desiredPrice > 0 || offeredPrice > 0) {
      final double maxPrice = max(desiredPrice, offeredPrice);
      final double minPrice = min(desiredPrice, offeredPrice);
      priceFairness = (minPrice / maxPrice) * 100.0;
    }

    // 2. Tag overlap score (0 to 100)
    final Set<String> setB = offeredTags.map((t) => t.trim().toLowerCase()).where((t) => t.isNotEmpty).toSet();
    double tagOverlap = 0.0;
    if (setA.isNotEmpty || setB.isNotEmpty) {
      final int intersection = setA.intersection(setB).length;
      final int union = setA.union(setB).length;
      tagOverlap = (intersection / union) * 100.0;
    }

    // 3. Weighted total
    final double total = (priceFairness * 0.6) + (tagOverlap * 0.4);

    results[id] = {
      'priceFairness': priceFairness,
      'tagOverlap': tagOverlap,
      'total': total,
    };
  }

  return results;
}
