import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'analytics_event.dart';

abstract class AnalyticsProvider {
  void track(AnalyticsEvent event);
  void setUserId(String? userId);
  void setUserProperty(String? value, {required String name});
  void reset();
}

class FirebaseAnalyticsProvider implements AnalyticsProvider {
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  @override
  void track(AnalyticsEvent event) {
    _analytics.logEvent(
      name: event.name,
      parameters: event.parameters.map((k, v) => MapEntry(k, v.firebaseValue)),
    );
  }

  @override
  void setUserId(String? userId) {
    _analytics.setUserId(id: userId);
  }

  @override
  void setUserProperty(String? value, {required String name}) {
    _analytics.setUserProperty(name: name, value: value);
  }

  @override
  void reset() {
    _analytics.setUserId(id: null);
  }
}

class FirestoreAnalyticsProvider implements AnalyticsProvider {
  FirestoreAnalyticsProvider({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  void track(AnalyticsEvent event) {
    final eventParams = event.parameters.map(
      (k, v) => MapEntry(k, v.firebaseValue),
    );

    DateTime eventTimestamp = DateTime.now().toUtc();
    final rawTimestamp = eventParams['timestamp'];
    if (rawTimestamp is String) {
      final parsed = DateTime.tryParse(rawTimestamp);
      if (parsed != null) {
        eventTimestamp = parsed.toUtc();
      }
    }

    final payload = <String, dynamic>{
      'event_name': event.name,
      'user_id': (eventParams['user_id'] ?? '').toString(),
      'timestamp': Timestamp.fromDate(eventTimestamp),
      'parameters': eventParams,
      'platform': (eventParams['platform'] ?? '').toString(),
      'source': (eventParams['source'] ?? '').toString(),
      'created_at': FieldValue.serverTimestamp(),
    };

    // Firestore fallback keeps events queryable without manual exported files.
    unawaited(
      _firestore.collection('analytics_events').add(payload).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        debugPrint('[Analytics] Firestore fallback write failed: $error');
      }),
    );
  }

  @override
  void setUserId(String? userId) {}

  @override
  void setUserProperty(String? value, {required String name}) {}

  @override
  void reset() {}
}

class AnalyticsService {
  static final AnalyticsService instance = AnalyticsService._();
  final List<AnalyticsProvider> _providers;
  final bool isDebugLoggingEnabled;
  String? _cachedAppVersion;

  // ─── Session tracking ──────────────────────────────────────────────────────
  /// Unique identifier for the current app session (generated on-demand).
  late final String _sessionId;
  String? _currentUserId;

  AnalyticsService._({
    List<AnalyticsProvider>? providers,
    this.isDebugLoggingEnabled = true,
  }) : _providers =
           providers ??
           [FirebaseAnalyticsProvider(), FirestoreAnalyticsProvider()] {
    _initializeSessionId();
  }

  /// Generates a unique session ID on first access (lazy initialization).
  void _initializeSessionId() {
    _sessionId = const Uuid().v4();
    if (isDebugLoggingEnabled) {
      debugPrint('[Analytics] Session initialized: $_sessionId');
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────────

  /// Returns the current session ID. Unique per app launch.
  String get sessionId => _sessionId;

  /// Returns the currently authenticated user ID, or null if not authenticated.
  String? get currentUserId => _currentUserId;

  void track(AnalyticsEvent event) {
    for (final provider in _providers) {
      provider.track(event);
    }
    if (isDebugLoggingEnabled) {
      final params = event.parameters.entries
          .map((e) => '${e.key}=${e.value.debugValue}')
          .join(', ');
      if (params.isEmpty) {
        debugPrint('[Analytics] ${event.name}');
      } else {
        debugPrint('[Analytics] ${event.name} {$params}');
      }
    }
  }

  void setUserId(String? userId) {
    _currentUserId = userId;
    for (final provider in _providers) {
      provider.setUserId(userId);
    }
    if (isDebugLoggingEnabled && userId != null) {
      debugPrint('[Analytics] User ID set: $userId');
    }
  }

  void setUserProperty(String? value, {required String name}) {
    for (final provider in _providers) {
      provider.setUserProperty(value, name: name);
    }
  }

  void reset() {
    _currentUserId = null;
    for (final provider in _providers) {
      provider.reset();
    }
    if (isDebugLoggingEnabled) {
      debugPrint('[Analytics] Session reset (user logged out)');
    }
  }

  // ---------------------------------------------------------------------------
  // Type-5 Business Question API
  // ---------------------------------------------------------------------------
  // Type 5 = feature effectiveness + business impact.
  // - ai_stylist_analysis_completed identifies feature users.
  // - user_app_opened enables 30-day retention measurements.
  // - recommendation clicked/saved events quantify marketplace engagement.

  void logAIStylistOpened({required String sourceScreen, String? userId}) {
    track(
      AnalyticsEvent.aiStylistOpened(
        userId: _effectiveUserId(userId),
        timestamp: _nowIso(),
        platform: _platformName(),
        sourceScreen: sourceScreen,
      ),
    );
  }

  void logAIStylistAnalysisCompleted({
    required String analysisId,
    required int imageCount,
    required bool fromCache,
    required String syncStatus,
    required int processingTimeMs,
    String? userId,
  }) {
    track(
      AnalyticsEvent.aiStylistAnalysisCompleted(
        userId: _effectiveUserId(userId),
        timestamp: _nowIso(),
        analysisId: analysisId,
        imageCount: imageCount,
        fromCache: fromCache,
        syncStatus: syncStatus,
        processingTimeMs: processingTimeMs,
      ),
    );
  }

  void logAIStylistRecommendationsViewed({
    required String analysisId,
    required int recommendationCount,
    String? userId,
  }) {
    track(
      AnalyticsEvent.aiStylistRecommendationsViewed(
        userId: _effectiveUserId(userId),
        timestamp: _nowIso(),
        analysisId: analysisId,
        recommendationCount: recommendationCount,
      ),
    );
  }

  void logAIStylistRecommendationClicked({
    required String analysisId,
    required String listingId,
    required String category,
    String? userId,
  }) {
    track(
      AnalyticsEvent.aiStylistRecommendationClicked(
        userId: _effectiveUserId(userId),
        timestamp: _nowIso(),
        analysisId: analysisId,
        listingId: listingId,
        category: category,
        source: 'ai_stylist',
      ),
    );
  }

  void logAIStylistListingSaved({
    required String analysisId,
    required String listingId,
    String? userId,
  }) {
    track(
      AnalyticsEvent.aiStylistListingSaved(
        userId: _effectiveUserId(userId),
        timestamp: _nowIso(),
        analysisId: analysisId,
        listingId: listingId,
        source: 'ai_stylist',
      ),
    );
  }

  Future<void> logUserAppOpened({String? userId}) async {
    final appVersion = await _resolveAppVersion();
    track(
      AnalyticsEvent.userAppOpened(
        userId: _effectiveUserId(userId),
        timestamp: _nowIso(),
        platform: _platformName(),
        appVersion: appVersion,
      ),
    );
  }

  String _effectiveUserId(String? explicitUserId) {
    final resolved = (explicitUserId ?? _currentUserId ?? 'anonymous').trim();
    return resolved.isEmpty ? 'anonymous' : resolved;
  }

  String _nowIso() => DateTime.now().toUtc().toIso8601String();

  String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  Future<String> _resolveAppVersion() async {
    if (_cachedAppVersion != null && _cachedAppVersion!.isNotEmpty) {
      return _cachedAppVersion!;
    }

    try {
      final info = await PackageInfo.fromPlatform();
      final build = info.buildNumber.trim();
      _cachedAppVersion =
          build.isEmpty ? info.version : '${info.version}+${info.buildNumber}';
      return _cachedAppVersion!;
    } catch (_) {
      _cachedAppVersion = 'unknown';
      return _cachedAppVersion!;
    }
  }
}
