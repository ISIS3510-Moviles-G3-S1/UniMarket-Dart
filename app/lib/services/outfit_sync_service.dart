import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../data/ai_outfit_local_storage_service.dart';
import 'ai_stylist_service.dart';

class OutfitSyncService extends ChangeNotifier {
  OutfitSyncService({AIStylistService? stylistService})
      : _stylistService = stylistService ?? AIStylistService();

  final AIStylistService _stylistService;
  final AIOutfitLocalStorageService _storage = AIOutfitLocalStorageService();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _started = false;
  bool _syncing = false;
  String? _lastError;

  bool get isSyncing => _syncing;
  String? get lastError => _lastError;

  void start() {
    if (_started) return;
    _started = true;

    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (_hasConnectivity(results)) {
        unawaited(syncPendingOutfitAnalyses());
      }
    });

    unawaited(syncPendingOutfitAnalyses());
  }

  Future<void> syncPendingOutfitAnalyses() async {
    if (_syncing) return;
    _syncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      if (!_hasConnectivity(connectivityResults)) {
        _syncing = false;
        notifyListeners();
        return;
      }

      final pending = await _storage.getPendingAnalyses();
      for (final analysis in pending) {
        try {
          final synced = await _stylistService.reanalyzePending(analysis);
          await _storage.markAsSynced(analysis.id, synced.copyWith(
            id: analysis.id,
            createdAt: analysis.createdAt,
            cacheKey: analysis.cacheKey,
            imagePaths: analysis.imagePaths,
            thumbnailPaths: analysis.thumbnailPaths,
          ));
        } catch (error) {
          await _storage.markAsFailed(analysis.id, analysis, errorMessage: error.toString());
          _lastError = error.toString();
        }
      }
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  bool _hasConnectivity(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}