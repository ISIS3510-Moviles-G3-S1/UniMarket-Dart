import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_activity.dart';

/// Service to track and persist user activity
class UserActivityService {
  static const String _activityKey = 'user_last_activity';
  
  /// Save user activity to persistent storage
  Future<void> recordActivity(String activityType) async {
    final prefs = await SharedPreferences.getInstance();
    final activity = UserActivity(
      lastInteractionTime: DateTime.now(),
      lastInteractionType: activityType,
    );
    
    await prefs.setString(_activityKey, jsonEncode(activity.toJson()));
  }

  /// Get the last user activity
  Future<UserActivity?> getLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final activityJson = prefs.getString(_activityKey);
    
    if (activityJson == null) return null;
    
    try {
      final Map<String, dynamic> data = jsonDecode(activityJson);
      return UserActivity.fromJson(data);
    } catch (e) {
      // If parsing fails, return null
      return null;
    }
  }

  /// Check if user is inactive (5+ days)
  Future<bool> isUserInactive() async {
    final activity = await getLastActivity();
    if (activity == null) {
      // No activity recorded, consider inactive
      return true;
    }
    return activity.isInactive;
  }

  /// Get days since last activity
  Future<int> getDaysSinceLastActivity() async {
    final activity = await getLastActivity();
    if (activity == null) {
      return 999; // Large number to indicate no activity
    }
    return activity.daysSinceLastInteraction;
  }

  /// Clear all activity data (for testing purposes)
  Future<void> clearActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activityKey);
  }
}
