/// Tracks user activity for context-aware features
class UserActivity {
  final DateTime lastInteractionTime;
  final String lastInteractionType; // 'like', 'buy', 'sell'

  const UserActivity({
    required this.lastInteractionTime,
    required this.lastInteractionType,
  });

  /// Calculate days since last interaction
  int get daysSinceLastInteraction {
    final now = DateTime.now();
    final difference = now.difference(lastInteractionTime);
    return difference.inDays;
  }

  /// Check if user is inactive (5+ days)
  bool get isInactive => daysSinceLastInteraction >= 5;

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'lastInteractionTime': lastInteractionTime.toIso8601String(),
      'lastInteractionType': lastInteractionType,
    };
  }

  /// Create from JSON
  factory UserActivity.fromJson(Map<String, dynamic> json) {
    return UserActivity(
      lastInteractionTime: DateTime.parse(json['lastInteractionTime'] as String),
      lastInteractionType: json['lastInteractionType'] as String,
    );
  }

  /// Create a copy with updated values
  UserActivity copyWith({
    DateTime? lastInteractionTime,
    String? lastInteractionType,
  }) {
    return UserActivity(
      lastInteractionTime: lastInteractionTime ?? this.lastInteractionTime,
      lastInteractionType: lastInteractionType ?? this.lastInteractionType,
    );
  }
}
