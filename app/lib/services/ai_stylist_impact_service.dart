import 'package:cloud_firestore/cloud_firestore.dart';

class AIStylistImpactStats {
  const AIStylistImpactStats({
    required this.aiStylistUsers,
    required this.returningAiStylistUsers,
    required this.recommendationClicks,
    required this.savedRecommendations,
    required this.aiStylistReturnRate,
    required this.comparisonUsers,
    required this.returningComparisonUsers,
    required this.comparisonReturnRate,
  });

  final int aiStylistUsers;
  final int returningAiStylistUsers;
  final int recommendationClicks;
  final int savedRecommendations;
  final double aiStylistReturnRate;
  final int comparisonUsers;
  final int returningComparisonUsers;
  final double comparisonReturnRate;
}

class AIStylistImpactService {
  AIStylistImpactService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AIStylistImpactStats> get30DayImpact() async {
    final snapshot = await _firestore.collection('analytics_events').get();

    final stylistCompletionsByUser = <String, List<DateTime>>{};
    final appOpensByUser = <String, List<DateTime>>{};
    var recommendationClicks = 0;
    var savedRecommendations = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final eventName = (data['event_name'] ?? '').toString();
      final userId = (data['user_id'] ?? '').toString().trim();
      if (userId.isEmpty || userId == 'anonymous') {
        continue;
      }

      final timestamp = _parseTimestamp(data['timestamp'], data['parameters']);
      if (timestamp == null) {
        continue;
      }

      if (eventName == 'ai_stylist_analysis_completed') {
        (stylistCompletionsByUser[userId] ??= <DateTime>[]).add(timestamp);
      }

      if (eventName == 'user_app_opened') {
        (appOpensByUser[userId] ??= <DateTime>[]).add(timestamp);
      }

      if (eventName == 'ai_stylist_recommendation_clicked') {
        final source = _extractSource(data['source'], data['parameters']);
        if (source == 'ai_stylist') {
          recommendationClicks += 1;
        }
      }

      if (eventName == 'ai_stylist_listing_saved') {
        final source = _extractSource(data['source'], data['parameters']);
        if (source == 'ai_stylist') {
          savedRecommendations += 1;
        }
      }
    }

    final stylistUsers = stylistCompletionsByUser.keys.toSet();
    final aiStylistUsers = stylistUsers.length;

    var returningAiStylistUsers = 0;
    for (final userId in stylistUsers) {
      final completions = stylistCompletionsByUser[userId]!..sort();
      final opens = (appOpensByUser[userId] ?? <DateTime>[])..sort();
      final firstCompletion = completions.first;

      final returnedWithin30Days = opens.any((openTime) {
        final delta = openTime.difference(firstCompletion).inDays;
        return delta > 0 && delta <= 30;
      });

      if (returnedWithin30Days) {
        returningAiStylistUsers += 1;
      }
    }

    final comparisonUsersSet =
        appOpensByUser.keys
            .where((userId) => !stylistUsers.contains(userId))
            .toSet();
    final comparisonUsers = comparisonUsersSet.length;

    var returningComparisonUsers = 0;
    for (final userId in comparisonUsersSet) {
      final opens = (appOpensByUser[userId] ?? <DateTime>[])..sort();
      if (opens.length < 2) continue;

      final baseline = opens.first;
      final returnedWithin30Days = opens.skip(1).any((openTime) {
        final delta = openTime.difference(baseline).inDays;
        return delta > 0 && delta <= 30;
      });

      if (returnedWithin30Days) {
        returningComparisonUsers += 1;
      }
    }

    // Type-5 BQ formulas:
    // AI Stylist return rate = returning_ai_stylist_users / ai_stylist_users
    // Comparison return rate = returning_comparison_users / comparison_users
    final aiStylistReturnRate =
        aiStylistUsers == 0 ? 0.0 : returningAiStylistUsers / aiStylistUsers;
    final comparisonReturnRate =
        comparisonUsers == 0 ? 0.0 : returningComparisonUsers / comparisonUsers;

    return AIStylistImpactStats(
      aiStylistUsers: aiStylistUsers,
      returningAiStylistUsers: returningAiStylistUsers,
      recommendationClicks: recommendationClicks,
      savedRecommendations: savedRecommendations,
      aiStylistReturnRate: aiStylistReturnRate,
      comparisonUsers: comparisonUsers,
      returningComparisonUsers: returningComparisonUsers,
      comparisonReturnRate: comparisonReturnRate,
    );
  }

  DateTime? _parseTimestamp(dynamic timestampField, dynamic parametersField) {
    if (timestampField is Timestamp) {
      return timestampField.toDate().toUtc();
    }
    if (timestampField is String) {
      final parsed = DateTime.tryParse(timestampField);
      if (parsed != null) return parsed.toUtc();
    }

    if (parametersField is Map<String, dynamic>) {
      final rawParamTimestamp = parametersField['timestamp'];
      if (rawParamTimestamp is String) {
        final parsed = DateTime.tryParse(rawParamTimestamp);
        if (parsed != null) return parsed.toUtc();
      }
    }

    return null;
  }

  String _extractSource(dynamic sourceField, dynamic parametersField) {
    final direct = (sourceField ?? '').toString().trim().toLowerCase();
    if (direct.isNotEmpty) {
      return direct;
    }

    if (parametersField is Map<String, dynamic>) {
      return (parametersField['source'] ?? '').toString().trim().toLowerCase();
    }

    return '';
  }
}
