import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'user_activity_service.dart';

/// Manages re-engagement notifications based on user inactivity
class ReEngagementNotificationManager {
  static const String _lastNotificationKey = 'last_reengagement_notification';
  static const int _inactivityThresholdDays = 5;
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final UserActivityService _activityService;

  ReEngagementNotificationManager({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    UserActivityService? activityService,
  })  : _notificationsPlugin = notificationsPlugin ?? FlutterLocalNotificationsPlugin(),
        _activityService = activityService ?? UserActivityService();

  /// Initialize notification settings
  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  /// Check inactivity and send notification if needed
  /// This should be called when app starts or periodically
  Future<void> checkAndNotifyInactivity() async {
    final days = await _activityService.getDaysSinceLastActivity();
    
    // Context-aware check: Is user inactive for 5+ days?
    if (days >= _inactivityThresholdDays) {
      // Check if we already sent a notification recently (avoid spam)
      final shouldSend = await _shouldSendNotification();
      if (shouldSend) {
        await _sendReEngagementNotification();
        await _recordNotificationSent();
      }
    }
  }

  /// Send the re-engagement notification
  Future<void> _sendReEngagementNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'reengagement_channel',
      'Re-engagement Notifications',
      channelDescription: 'Notifications to bring inactive users back to the app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      0, // Notification ID
      'UniMarket',
      'New items are waiting for you!',
      notificationDetails,
    );
  }

  /// Check if we should send a notification (avoid sending too frequently)
  Future<bool> _shouldSendNotification() async {
    final prefs = await SharedPreferences.getInstance();
    final lastNotificationTimeStr = prefs.getString(_lastNotificationKey);
    
    if (lastNotificationTimeStr == null) return true;
    
    final lastNotificationTime = DateTime.parse(lastNotificationTimeStr);
    final daysSinceLastNotification = DateTime.now().difference(lastNotificationTime).inDays;
    
    // Only send notification once every 7 days to avoid spam
    return daysSinceLastNotification >= 7;
  }

  /// Record that we sent a notification
  Future<void> _recordNotificationSent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastNotificationKey, DateTime.now().toIso8601String());
  }

  /// Get current inactivity status (for debugging/display)
  Future<Map<String, dynamic>> getInactivityStatus() async {
    final days = await _activityService.getDaysSinceLastActivity();
    final activity = await _activityService.getLastActivity();
    
    return {
      'daysSinceLastActivity': days,
      'isInactive': days >= _inactivityThresholdDays,
      'lastActivityType': activity?.lastInteractionType ?? 'none',
      'lastActivityTime': activity?.lastInteractionTime.toIso8601String() ?? 'never',
    };
  }

  /// Request notification permissions (especially for iOS)
  Future<bool> requestPermissions() async {
    if (_notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>() !=
        null) {
      final granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()!
          .requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    }
    
    if (_notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>() !=
        null) {
      final granted = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!
          .requestNotificationsPermission();
      return granted ?? false;
    }
    
    return true;
  }
}
