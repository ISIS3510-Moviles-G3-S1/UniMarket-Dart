import 'package:hive/hive.dart';

import '../models/ai_outfit_analysis.dart';

class AIOutfitLocalStorageService {
  static const String boxName = 'ai_outfit_analyses_v1';

  Box? _boxCache;
  Future<Box> _openBox() async {
    if (_boxCache?.isOpen == true) return _boxCache!;
    _boxCache = await Hive.openBox(boxName);
    return _boxCache!;
  }

  Future<void> saveAnalysis(AIOutfitAnalysis analysis) async {
    final box = await _openBox();
    await box.put(analysis.id, analysis.toJson());
  }

  Future<AIOutfitAnalysis?> getById(String id) async {
    if (id.trim().isEmpty) return null;
    final box = await _openBox();
    final raw = box.get(id);
    if (raw is Map) {
      try {
        return AIOutfitAnalysis.fromJson(Map<dynamic, dynamic>.from(raw));
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<AIOutfitAnalysis?> getByCacheKey(String cacheKey) async {
    if (cacheKey.trim().isEmpty) return null;
    final box = await _openBox();
    for (final value in box.values) {
      if (value is Map) {
        try {
          final analysis = AIOutfitAnalysis.fromJson(Map<dynamic, dynamic>.from(value));
          if (analysis.cacheKey == cacheKey) {
            return analysis;
          }
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  Future<List<AIOutfitAnalysis>> getHistory({int limit = 20}) async {
    final box = await _openBox();
    final analyses = <AIOutfitAnalysis>[];

    for (final value in box.values) {
      if (value is! Map) continue;
      try {
        analyses.add(AIOutfitAnalysis.fromJson(Map<dynamic, dynamic>.from(value)));
      } catch (_) {
        continue;
      }
    }

    analyses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (limit <= 0) return analyses;
    return analyses.take(limit).toList(growable: false);
  }

  Future<List<AIOutfitAnalysis>> getPendingAnalyses() async {
    final history = await getHistory(limit: 0);
    return history.where((analysis) => analysis.syncStatus == AIOutfitSyncStatus.pending).toList(growable: false);
  }

  Future<void> markAsSynced(String id, AIOutfitAnalysis analysis) async {
    final box = await _openBox();
    await box.put(id, analysis.copyWith(syncStatus: AIOutfitSyncStatus.synced).toJson());
  }

  Future<void> markAsFailed(String id, AIOutfitAnalysis analysis, {String? errorMessage}) async {
    final box = await _openBox();
    await box.put(
      id,
      analysis.copyWith(
        syncStatus: AIOutfitSyncStatus.failed,
        errorMessage: errorMessage ?? analysis.errorMessage,
      ).toJson(),
    );
  }
}