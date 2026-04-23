import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../analytics_service.dart';
import '../analytics_event.dart';
import 'theme_strategy.dart';
import 'day_theme_strategy.dart';
import 'night_theme_strategy.dart';

enum ThemeSelectionMode { automatic, light, dark }

/// [Strategy Pattern] — Context class that owns and delegates to a [ThemeStrategy].
///
/// In the Strategy pattern the "context" is the object whose behaviour
/// varies at runtime.  Here the varying behaviour is *which theme is shown*.
/// [ThemeContext] does NOT know how to build a theme — it delegates that
/// entirely to the active [ThemeStrategy].
///
/// Responsibilities of this class:
///   1. Hold a reference to the currently active [ThemeStrategy].
///   2. Automatically pick the right strategy based on the time of day.
///   3. Poll every minute so the theme switches at the correct hour even if
///      the user keeps the app open across the 6 AM / 7 PM boundary.
///   4. Expose [setStrategy] so callers can inject a manual override
///      (user preference, ambient-light sensor, battery-saving mode, etc.)
///      without touching any other class.
///   5. Track theme switches in analytics for BigQuery reporting.
///
/// Extends [ChangeNotifier] so that the Flutter widget tree is rebuilt
/// automatically whenever the active strategy changes.
///
/// --- How to extend ---
/// To add a new strategy without changing existing code:
///   1. Implement [ThemeStrategy] in a new class.
///   2. Either add it to the [strategies] list passed to the constructor
///      (for automatic time/condition-based switching), or call [setStrategy]
///      at runtime for an imperative override.
class ThemeContext extends ChangeNotifier {
  static const String _themeSelectionStorageKeyBase = 'theme_selection_mode_v1';
  static const String _lastThemeStorageKeyBase = 'theme_last_active_v1';

  /// Ordered list of strategies evaluated for automatic switching.
  /// The first strategy whose [ThemeStrategy.isActiveFor] returns `true` wins.
  final List<ThemeStrategy> _autoStrategies;

  ThemeStrategy _currentStrategy;
  Timer? _pollingTimer;
  StreamSubscription<User?>? _authSub;

  /// `true` while a manual strategy override is in effect.
  bool _manualOverride = false;

  /// `true` after the initial theme has been set (prevents duplicate init events).
  bool _isInitialized = false;

  ThemeSelectionMode _selectionMode = ThemeSelectionMode.automatic;

  /// Cached analytics service for tracking theme changes.
  final AnalyticsService _analytics = AnalyticsService.instance;

  /// Creates a [ThemeContext] with an optional custom [strategies] list.
  ///
  /// If [strategies] is omitted the default list is
  /// `[DayThemeStrategy(), NightThemeStrategy()]`, which covers all hours.
  ///
  /// The correct strategy for the current time is resolved immediately,
  /// and a background timer starts polling every minute.
  ThemeContext({List<ThemeStrategy>? strategies})
      : _autoStrategies = strategies ??
            [
              DayThemeStrategy(),
              NightThemeStrategy(),
            ],
        _currentStrategy = _resolve(
          strategies ?? [DayThemeStrategy(), NightThemeStrategy()],
          DateTime.now(),
        ) {
    _startPolling();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((_) {
      unawaited(_restoreSelectionMode());
    });
    unawaited(_restoreSelectionMode());
    // Fire session initialization event on next frame
    Future.microtask(() => _fireSessionInitializedEvent());
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  /// The [ThemeData] produced by the currently active strategy.
  ///
  /// Widgets bind to this through a [Consumer<ThemeContext>] or
  /// `context.watch<ThemeContext>().currentTheme`.
  ThemeData get currentTheme => _currentStrategy.getTheme();

  /// The strategy instance that is currently in use (useful for debugging
  /// or showing a UI indicator of which mode is active).
  ThemeStrategy get activeStrategy => _currentStrategy;

  /// Whether a manual override is currently suppressing the automatic
  /// time-based strategy selection.
  bool get isManualOverride => _manualOverride;

  /// Current user-selected mode exposed to the UI.
  ThemeSelectionMode get selectionMode => _selectionMode;

  /// Forces [strategy] to be the active strategy, bypassing the automatic
  /// time-based check.
  ///
  /// The polling timer is paused while an override is active so the
  /// manual choice is not silently overwritten a minute later.
  ///
  /// Example — night mode on demand:
  /// ```dart
  /// context.read<ThemeContext>().setStrategy(NightThemeStrategy());
  /// ```
  void setStrategy(ThemeStrategy strategy) {
    _setManualStrategy(strategy, trackAnalyticsEvents: true);
  }

  void _setManualStrategy(
    ThemeStrategy strategy, {
    required bool trackAnalyticsEvents,
  }) {
    _selectionMode = _modeForStrategy(strategy);
    unawaited(_persistSelectionMode(_selectionMode));

    final previousTheme = _getThemeName(_currentStrategy);
    final newTheme = _getThemeName(strategy);

    _manualOverride = true;
    _pollingTimer?.cancel();

    if (trackAnalyticsEvents) {
      // Fire manual override event BEFORE applying the new strategy.
      _fireManualOverrideEvent(
        fromTheme: previousTheme,
        toTheme: newTheme,
      );

      _fireThemePreferenceSelectedEvent(
        preferenceMode: 'manual',
        selectedTheme: newTheme,
      );
    }

    _applyStrategy(strategy);
  }

  /// Reverts to automatic time-based strategy selection and restarts
  /// the polling timer.
  void clearManualOverride() {
    setAutomaticMode();
  }

  /// Enables automatic time-based switching.
  void setAutomaticMode({
    bool trackPreferenceEvent = true,
    bool syncToCurrentTime = true,
  }) {
    _selectionMode = ThemeSelectionMode.automatic;
    unawaited(_persistSelectionMode(_selectionMode));
    _manualOverride = false;

    if (syncToCurrentTime) {
      _autoSwitch();
    }

    _startPolling();

    if (trackPreferenceEvent) {
      _fireThemePreferenceSelectedEvent(
        preferenceMode: 'automatic',
        selectedTheme: _getThemeName(_currentStrategy),
      );
    }

    notifyListeners();
  }

  /// Locks theme to light mode.
  void setLightMode() => _setManualStrategy(DayThemeStrategy(), trackAnalyticsEvents: true);

  /// Locks theme to dark mode.
  void setDarkMode() => _setManualStrategy(NightThemeStrategy(), trackAnalyticsEvents: true);

  Future<void> _restoreSelectionMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = _currentPreferenceScope();
      final storedValue = prefs.getString(_themeSelectionStorageKeyForScope(scope));
      final lastThemeName = prefs.getString(_lastThemeStorageKeyForScope(scope));

      final lastThemeStrategy = _strategyForThemeName(lastThemeName);
      if (lastThemeStrategy != null) {
        _currentStrategy = lastThemeStrategy;
      }

      switch (storedValue) {
        case 'light':
          _setManualStrategy(DayThemeStrategy(), trackAnalyticsEvents: false);
          break;
        case 'dark':
          _setManualStrategy(NightThemeStrategy(), trackAnalyticsEvents: false);
          break;
        case 'automatic':
          setAutomaticMode(
            trackPreferenceEvent: false,
            syncToCurrentTime: false,
          );
          break;
        default:
          if (lastThemeStrategy != null) {
            notifyListeners();
          }
      }
    } catch (_) {
      // Keep default automatic behavior if persistence is unavailable.
    }
  }

  Future<void> _persistSelectionMode(ThemeSelectionMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _themeSelectionStorageKeyForScope(_currentPreferenceScope()),
        mode.name,
      );
    } catch (_) {
      // Ignore persistence errors; theme selection still works in-memory.
    }
  }

  /// Pauses the background polling timer.
  ///
  /// Call this in tests or when the app enters the background to avoid
  /// unnecessary work.  Resume by calling [clearManualOverride] or by
  /// creating a new [ThemeContext].
  void stopAutoSwitch() => _pollingTimer?.cancel();

  // ─── Internal helpers ─────────────────────────────────────────────────────

  /// Picks the first strategy whose [ThemeStrategy.isActiveFor] returns
  /// `true` for [now].  Falls back to the last strategy in the list if
  /// none matches (should never happen with the default list).
  static ThemeStrategy _resolve(
    List<ThemeStrategy> strategies,
    DateTime now,
  ) {
    return strategies.firstWhere(
      (s) => s.isActiveFor(now),
      orElse: () => strategies.last,
    );
  }

  /// Converts a [ThemeStrategy] to a human-readable theme name.
  String _getThemeName(ThemeStrategy strategy) {
    if (strategy is DayThemeStrategy) return 'light';
    if (strategy is NightThemeStrategy) return 'dark';
    return 'unknown';
  }

  ThemeSelectionMode _modeForStrategy(ThemeStrategy strategy) {
    if (strategy is DayThemeStrategy) return ThemeSelectionMode.light;
    if (strategy is NightThemeStrategy) return ThemeSelectionMode.dark;
    return ThemeSelectionMode.automatic;
  }

  ThemeStrategy? _strategyForThemeName(String? themeName) {
    switch (themeName) {
      case 'light':
        return DayThemeStrategy();
      case 'dark':
        return NightThemeStrategy();
      default:
        return null;
    }
  }

  Future<void> _persistLastThemeName(String themeName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _lastThemeStorageKeyForScope(_currentPreferenceScope()),
        themeName,
      );
    } catch (_) {
      // Ignore persistence errors; theme selection still works in-memory.
    }
  }

  String _currentPreferenceScope() {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid.trim() ?? '';
    if (uid.isNotEmpty) {
      return 'uid_$uid';
    }
    return 'guest';
  }

  String _themeSelectionStorageKeyForScope(String scope) {
    return '${_themeSelectionStorageKeyBase}_$scope';
  }

  String _lastThemeStorageKeyForScope(String scope) {
    return '${_lastThemeStorageKeyBase}_$scope';
  }

  /// Starts a one-minute polling timer that re-evaluates the active
  /// strategy on every tick.
  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_manualOverride) _autoSwitch();
    });
  }

  /// Checks whether the active strategy should change and notifies
  /// listeners only when it actually does.
  void _autoSwitch() {
    final best = _resolve(_autoStrategies, DateTime.now());
    if (best.runtimeType != _currentStrategy.runtimeType) {
      final previousTheme = _getThemeName(_currentStrategy);
      final newTheme = _getThemeName(best);

      // Fire automatic switch event BEFORE applying the new strategy
      _fireAutoSwitchEvent(
        fromTheme: previousTheme,
        toTheme: newTheme,
      );

      _applyStrategy(best);
    }
  }

  /// Updates [_currentStrategy] and notifies all listeners.
  void _applyStrategy(ThemeStrategy strategy) {
    _currentStrategy = strategy;
    unawaited(_persistLastThemeName(_getThemeName(strategy)));
    notifyListeners();
  }

  // ─── Analytics Events ──────────────────────────────────────────────────────

  /// Fires the session initialization event (once per session).
  void _fireSessionInitializedEvent() {
    if (_isInitialized) return;
    _isInitialized = true;

    final now = DateTime.now();
    final themeName = _getThemeName(_currentStrategy);

    _analytics.track(
      AnalyticsEvent.sessionThemeInitialized(
        sessionId: _analytics.sessionId,
        userId: _analytics.currentUserId,
        initialTheme: themeName,
        hourOfDay: now.hour,
        timestamp: now.toIso8601String(),
      ),
    );
  }

  /// Fires an event when an automatic (time-based) theme switch occurs.
  void _fireAutoSwitchEvent({
    required String fromTheme,
    required String toTheme,
  }) {
    final now = DateTime.now();

    _analytics.track(
      AnalyticsEvent.themeAutoSwitched(
        sessionId: _analytics.sessionId,
        userId: _analytics.currentUserId,
        fromTheme: fromTheme,
        toTheme: toTheme,
        hourOfDay: now.hour,
        timestamp: now.toIso8601String(),
        switchReason: 'time_based',
      ),
    );
  }

  /// Fires an event when a manual theme override is applied.
  void _fireManualOverrideEvent({
    required String fromTheme,
    required String toTheme,
  }) {
    final now = DateTime.now();

    _analytics.track(
      AnalyticsEvent.themeManualOverride(
        sessionId: _analytics.sessionId,
        userId: _analytics.currentUserId,
        fromTheme: fromTheme,
        toTheme: toTheme,
        overrideReason: 'user_preference',
        timestamp: now.toIso8601String(),
      ),
    );
  }

  void _fireThemePreferenceSelectedEvent({
    required String preferenceMode,
    required String selectedTheme,
  }) {
    final now = DateTime.now();

    _analytics.track(
      AnalyticsEvent.themePreferenceSelected(
        sessionId: _analytics.sessionId,
        userId: _analytics.currentUserId,
        preferenceMode: preferenceMode,
        selectedTheme: selectedTheme,
        timestamp: now.toIso8601String(),
      ),
    );
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
