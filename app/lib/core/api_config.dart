class APIConfig {
  APIConfig._();

  static const String openRouterUrl = 'https://openrouter.ai/api/v1/chat/completions';
  static const String openRouterApiKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const String openRouterModel = String.fromEnvironment(
    'OPENROUTER_MODEL',
    defaultValue: 'openai/gpt-4o-mini',
  );
}
