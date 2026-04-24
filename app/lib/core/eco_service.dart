import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import '../models/sustainability_impact.dart';

class EcoService {
  EcoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _systemMessage =
      "You are Eco, a friendly and motivational sustainability companion inside UniMarket, a student marketplace app for clothing only. Your job is to celebrate the user's progress and give them one specific, encouraging nudge based on their stats. Tone: warm, upbeat, like a supportive friend — never preachy or generic. Always address the user by name. Reference their actual numbers (XP, transactions, listings sold) to make it feel personal. Max 240 characters total.";

  Future<String> generateRecommendation({
    required String displayName,
    required num rating,
    required int xp,
    required String levelTitle,
    required int xpToNext,
    required int soldCount,
    required int transactions,
  }) async {
    if (APIConfig.openRouterApiKey.trim().isEmpty) {
      throw const EcoServiceException('API failure');
    }

    final prompt = '''Create one personalized sustainability recommendation for this user.
Name: $displayName
Rating: $rating/5
XP: $xp
Sustainability level: $levelTitle
XP to next level: $xpToNext
Number of listings sold: $soldCount
Total transactions: $transactions''';

    final response = await _client.post(
      Uri.parse(APIConfig.openRouterUrl),
      headers: {
        'Authorization': 'Bearer ${APIConfig.openRouterApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': APIConfig.openRouterModel,
        'messages': [
          {'role': 'system', 'content': _systemMessage},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const EcoServiceException('API failure');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const EcoServiceException('invalid response');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const EcoServiceException('invalid response');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      throw const EcoServiceException('invalid response');
    }

    final message = firstChoice['message'];
    if (message is! Map<String, dynamic>) {
      throw const EcoServiceException('invalid response');
    }

    final content = message['content'];
    String text;
    if (content is String) {
      text = content.trim();
    } else {
      throw const EcoServiceException('invalid response');
    }

    if (text.isEmpty) {
      throw const EcoServiceException('empty content');
    }

    return text;
  }

  Future<String> generateImpactInsight({
    required SustainabilityImpact impact,
    required String displayName,
  }) async {
    if (APIConfig.openRouterApiKey.trim().isEmpty) {
      throw const EcoServiceException('API failure');
    }

    const system = 'You are Eco, UniMarket\'s sustainability analyst. You turn a student\'s real reuse '
        'numbers into one sharp, data-grounded insight that feels personal. Follow these rules strictly:\n'
        '1. Open with ONE vivid, concrete comparison tied to the biggest number (showers of water, '
        'km of driving avoided, or tree-years of CO2).\n'
        '2. Call out the user\'s STRONGEST category by name and why it over-indexes '
        '(e.g., "your jackets alone carry most of that water saving").\n'
        '3. End with ONE specific, non-generic next action tied to what they already do well.\n'
        'Rules: warm, direct tone. No emojis. No hashtags. No preachy climate platitudes. '
        'No round-number invention — use only the numbers provided. '
        'Maximum 3 short sentences, 320 characters total.';

    final topCat = impact.topCategories.isNotEmpty
        ? impact.topCategories.first.key.displayName
        : 'clothing';

    final prompt = '''Name: $displayName
Items reused: ${impact.itemsReused}
Water spared: ${impact.waterLiters} litres (= ${impact.showerEquivalents} showers)
CO2 avoided: ${impact.co2Kg.toStringAsFixed(1)} kg (= ${impact.drivingKilometersAvoided} km not driven, ${impact.treeYearsEquivalent} tree-years)
Waste diverted: ${impact.wasteKg.toStringAsFixed(1)} kg
Top category: $topCat''';

    final response = await _client.post(
      Uri.parse(APIConfig.openRouterUrl),
      headers: {
        'Authorization': 'Bearer ${APIConfig.openRouterApiKey}',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': APIConfig.openRouterModel,
        'messages': [
          {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const EcoServiceException('API failure');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const EcoServiceException('invalid response');
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw const EcoServiceException('invalid response');
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      throw const EcoServiceException('invalid response');
    }

    final message = firstChoice['message'];
    if (message is! Map<String, dynamic>) {
      throw const EcoServiceException('invalid response');
    }

    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw const EcoServiceException('empty content');
    }

    return content.trim();
  }
}

class EcoServiceException implements Exception {
  const EcoServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
