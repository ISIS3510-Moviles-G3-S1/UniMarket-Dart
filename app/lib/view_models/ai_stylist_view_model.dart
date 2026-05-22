import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/analytics_service.dart';
import '../data/ai_outfit_local_storage_service.dart';
import '../models/ai_outfit_analysis.dart';
import '../models/listing.dart';
import '../services/ai_stylist_service.dart';
import '../services/outfit_sync_service.dart';

class AIStylistViewModel extends ChangeNotifier {
  AIStylistViewModel({required OutfitSyncService syncService})
    : _syncService = syncService {
    _syncService.addListener(_handleSyncUpdate);
    unawaited(loadHistory());
  }

  final OutfitSyncService _syncService;
  final AIStylistService _stylistService = AIStylistService();
  final AIOutfitLocalStorageService _storage = AIOutfitLocalStorageService();
  final ImagePicker _picker = ImagePicker();
  final AnalyticsService _analytics = AnalyticsService.instance;

  final List<XFile> _selectedImages = [];
  final Set<String> _recommendationsViewedTrackedAnalysisIds = <String>{};
  List<AIOutfitAnalysis> _history = [];
  List<Listing> _recommendedListings = [];
  AIOutfitAnalysis? _currentAnalysis;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _statusMessage;

  List<XFile> get selectedImages => List.unmodifiable(_selectedImages);
  List<AIOutfitAnalysis> get history => List.unmodifiable(_history);
  List<Listing> get recommendedListings =>
      List.unmodifiable(_recommendedListings);
  AIOutfitAnalysis? get currentAnalysis => _currentAnalysis;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isSyncing => _syncService.isSyncing;
  String? get errorMessage => _errorMessage;
  String? get statusMessage => _statusMessage;
  bool get canAnalyze =>
      _selectedImages.isNotEmpty && _selectedImages.length <= 3;

  void onViewOpened({String sourceScreen = 'profile_screen'}) {
    _analytics.logAIStylistOpened(sourceScreen: sourceScreen);
  }

  Future<void> loadHistory() async {
    _history = await _storage.getHistory(limit: 30);
    if (_currentAnalysis != null) {
      final refreshed =
          _history
              .where((analysis) => analysis.id == _currentAnalysis!.id)
              .toList();
      if (refreshed.isNotEmpty) {
        _currentAnalysis = refreshed.first;
      }
    }
    notifyListeners();
  }

  Future<void> pickImages() async {
    try {
      final images = await _picker.pickMultiImage(imageQuality: 90);
      if (images.isEmpty) return;

      final combined = [..._selectedImages, ...images];
      if (combined.length > 3) {
        _selectedImages
          ..clear()
          ..addAll(combined.take(3));
        _errorMessage = 'You can analyze up to 3 clothing images at a time.';
        _statusMessage = 'Only the first 3 images were kept.';
      } else {
        _selectedImages
          ..clear()
          ..addAll(combined);
        _errorMessage = null;
      }

      notifyListeners();
    } catch (error) {
      _errorMessage = 'Could not read the selected images: $error';
      notifyListeners();
    }
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= _selectedImages.length) return;
    _selectedImages.removeAt(index);
    notifyListeners();
  }

  Future<void> analyzeSelectedImages() async {
    if (_selectedImages.isEmpty) {
      _errorMessage = 'Please select one to three clothing images first.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();

    final stopwatch = Stopwatch()..start();

    try {
      final analysis = await _stylistService.analyzeOutfit(_selectedImages);
      _currentAnalysis = analysis;
      await _refreshRecommendations();
      await loadHistory();

      // Type-5 BQ: successful analysis completion marks feature adoption group.
      if (analysis.syncStatus != AIOutfitSyncStatus.failed) {
        _analytics.logAIStylistAnalysisCompleted(
          analysisId: analysis.id,
          imageCount: _selectedImages.length,
          fromCache: analysis.fromCache,
          syncStatus: aiOutfitSyncStatusToString(analysis.syncStatus),
          processingTimeMs: stopwatch.elapsedMilliseconds,
        );
      }

      if (analysis.syncStatus == AIOutfitSyncStatus.pending) {
        _statusMessage = 'Pending analysis - will sync when internet returns';
      } else if (analysis.fromCache) {
        _statusMessage = 'Loaded from cache';
      } else if (analysis.syncStatus == AIOutfitSyncStatus.failed) {
        _statusMessage =
            'AI analysis failed. Showing a local fallback preview.';
      } else {
        _statusMessage = 'Analysis complete.';
      }
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      stopwatch.stop();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveCurrentAnalysis() async {
    final analysis = _currentAnalysis;
    if (analysis == null) return;

    _isSaving = true;
    notifyListeners();
    try {
      await _storage.saveAnalysis(analysis);
      await loadHistory();
      _statusMessage = 'Outfit analysis saved to history.';
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> openHistoryAnalysis(AIOutfitAnalysis analysis) async {
    _currentAnalysis = analysis;
    _selectedImages
      ..clear()
      ..addAll(
        (analysis.thumbnailPaths.isNotEmpty
                ? analysis.thumbnailPaths
                : analysis.imagePaths)
            .map((path) => XFile(path)),
      );
    await _refreshRecommendations();
    _statusMessage =
        analysis.syncStatus == AIOutfitSyncStatus.pending
            ? 'Pending analysis - will sync when internet returns'
            : 'Showing saved analysis.';
    notifyListeners();
  }

  Future<void> clearSelection() async {
    _selectedImages.clear();
    _currentAnalysis = null;
    _recommendedListings = [];
    _errorMessage = null;
    _statusMessage = null;
    notifyListeners();
  }

  Future<void> _refreshRecommendations() async {
    final analysis = _currentAnalysis;
    if (analysis == null) {
      _recommendedListings = [];
      return;
    }

    try {
      _recommendedListings = await _stylistService.getRecommendedListings(
        analysis,
      );

      // Type-5 BQ: recommendation visibility is part of marketplace engagement funnel.
      if (_recommendedListings.isNotEmpty &&
          !_recommendationsViewedTrackedAnalysisIds.contains(analysis.id)) {
        _recommendationsViewedTrackedAnalysisIds.add(analysis.id);
        _analytics.logAIStylistRecommendationsViewed(
          analysisId: analysis.id,
          recommendationCount: _recommendedListings.length,
        );
      }
    } catch (_) {
      _recommendedListings = [];
    }
  }

  void logRecommendationClicked(Listing listing) {
    final analysis = _currentAnalysis;
    if (analysis == null) return;

    // `source = ai_stylist` isolates interactions driven by this feature.
    _analytics.logAIStylistRecommendationClicked(
      analysisId: analysis.id,
      listingId: listing.id,
      category: listing.tags.isNotEmpty ? listing.tags.first : 'unknown',
    );
  }

  void logRecommendationSaved(Listing listing) {
    final analysis = _currentAnalysis;
    if (analysis == null) return;

    _analytics.logAIStylistListingSaved(
      analysisId: analysis.id,
      listingId: listing.id,
    );
  }

  void _handleSyncUpdate() {
    unawaited(_handleSyncUpdateAsync());
  }

  Future<void> _handleSyncUpdateAsync() async {
    await loadHistory();
    final current = _currentAnalysis;
    if (current == null) return;

    final refreshed =
        _history.where((analysis) => analysis.id == current.id).toList();
    if (refreshed.isNotEmpty) {
      _currentAnalysis = refreshed.first;
      await _refreshRecommendations();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _syncService.removeListener(_handleSyncUpdate);
    super.dispose();
  }
}
