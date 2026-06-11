/// Configuration profile for Claude Code settings.
///
/// This data is written to `~/.claude/settings.json` and `~/.claude.json`.
class ConfigProfile {
  /// API authentication token (ANTHROPIC_AUTH_TOKEN)
  final String? apiKey;

  /// Custom base URL for the API (ANTHROPIC_BASE_URL)
  final String? baseUrl;

  /// Whether to skip the onboarding flow (hasCompletedOnboarding)
  final bool skipOnboarding;

  /// Full model ID for the Opus alias
  final String? opusModelId;

  /// Full model ID for the Sonnet alias
  final String? sonnetModelId;

  /// Full model ID for the Haiku alias
  final String? haikuModelId;

  /// Additional environment variables to write
  final Map<String, String> extraEnv;

  const ConfigProfile({
    this.apiKey,
    this.baseUrl,
    this.skipOnboarding = true,
    this.opusModelId,
    this.sonnetModelId,
    this.haikuModelId,
    this.extraEnv = const {},
  });

  /// Creates an empty profile with default values
  factory ConfigProfile.empty() {
    return const ConfigProfile(
      skipOnboarding: true,
    );
  }

  /// Creates a profile for DeepSeek API (pre-configured)
  factory ConfigProfile.deepSeek({
    required String apiKey,
    String baseUrl = 'https://api.deepseek.com/anthropic',
  }) {
    return ConfigProfile(
      apiKey: apiKey,
      baseUrl: baseUrl,
      skipOnboarding: true,
      sonnetModelId: 'deepseek-v4-pro[1m]',
      opusModelId: 'deepseek-v4-pro[1m]',
      haikuModelId: 'deepseek-v4-flash',
    );
  }

  /// Creates a profile for Anthropic official API
  factory ConfigProfile.anthropicOfficial({required String apiKey}) {
    return ConfigProfile(
      apiKey: apiKey,
      skipOnboarding: true,
    );
  }

  /// Build the settings.json content as a Map
  Map<String, dynamic> toSettingsJson() {
    final env = <String, String>{};

    if (apiKey != null && apiKey!.isNotEmpty) {
      env['ANTHROPIC_AUTH_TOKEN'] = apiKey!;
    }
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      env['ANTHROPIC_BASE_URL'] = baseUrl!;
    }
    if (sonnetModelId != null && sonnetModelId!.isNotEmpty) {
      env['ANTHROPIC_DEFAULT_SONNET_MODEL'] = sonnetModelId!;
    }
    if (opusModelId != null && opusModelId!.isNotEmpty) {
      env['ANTHROPIC_DEFAULT_OPUS_MODEL'] = opusModelId!;
    }
    if (haikuModelId != null && haikuModelId!.isNotEmpty) {
      env['ANTHROPIC_DEFAULT_HAIKU_MODEL'] = haikuModelId!;
    }

    // Merge extra env vars
    env.addAll(extraEnv);

    return {
      'env': env,
    };
  }

  /// Build the .claude.json content as a Map
  Map<String, dynamic> toClaudeJson() {
    return {
      'hasCompletedOnboarding': true,
    };
  }

  ConfigProfile copyWith({
    String? apiKey,
    String? baseUrl,
    bool? skipOnboarding,
    String? opusModelId,
    String? sonnetModelId,
    String? haikuModelId,
    Map<String, String>? extraEnv,
    bool clearApiKey = false,
    bool clearBaseUrl = false,
  }) {
    return ConfigProfile(
      apiKey: clearApiKey ? null : (apiKey ?? this.apiKey),
      baseUrl: clearBaseUrl ? null : (baseUrl ?? this.baseUrl),
      skipOnboarding: skipOnboarding ?? this.skipOnboarding,
      opusModelId: opusModelId ?? this.opusModelId,
      sonnetModelId: sonnetModelId ?? this.sonnetModelId,
      haikuModelId: haikuModelId ?? this.haikuModelId,
      extraEnv: extraEnv ?? this.extraEnv,
    );
  }
}
