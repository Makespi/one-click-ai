import 'dart:convert';
import 'dart:io' show File, Directory, Platform;

import '../models/config_profile.dart';

/// Service to read and write Claude Code configuration files.
///
/// Writes to:
/// - `~/.claude/settings.json` (environment variables and model config)
/// - `~/.claude.json` (onboarding bypass flag)
class ConfigService {
  /// Get the path to the .claude config directory.
  String get claudeDirPath {
    final home = _homeDir;
    if (Platform.isWindows) {
      return '$home\\.claude';
    }
    return '$home/.claude';
  }

  /// Get the path to settings.json
  String get settingsPath => '$_claudeDirPath${Platform.isWindows ? '\\' : '/'}settings.json';

  /// Get the path to .claude.json
  String get claudeJsonPath => '$_claudeDirPath${Platform.isWindows ? '\\' : '/'}.claude.json';

  String get _claudeDirPath => claudeDirPath;

  String get _homeDir {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return env['USERPROFILE'] ?? env['HOMEDRIVE'] ?? r'C:\Users\Default';
    }
    return env['HOME'] ?? '/home';
  }

  /// Write the settings.json file with the given profile.
  Future<void> writeSettings(ConfigProfile profile) async {
    // Ensure the .claude directory exists
    final dir = Directory(_claudeDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Read existing settings if any, and merge
    final existing = await readExistingSettings();
    final merged = _mergeSettings(existing, profile.toSettingsJson());

    // Write with pretty formatting
    final file = File(settingsPath);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(merged));
  }

  /// Write .claude.json to bypass the onboarding flow.
  Future<void> writeOnboardingBypass() async {
    final dir = Directory(_claudeDirPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final file = File(claudeJsonPath);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert({
      'hasCompletedOnboarding': true,
    }));
  }

  /// Read existing settings.json, returns empty map if not found.
  Future<Map<String, dynamic>> readExistingSettings() async {
    final file = File(settingsPath);
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      } catch (_) {
        // If parsing fails, return empty and overwrite
      }
    }
    return {};
  }

  /// Read the current ConfigProfile from settings.json.
  /// Returns null if no settings file exists.
  Future<ConfigProfile?> readSettings() async {
    final existing = await readExistingSettings();
    if (existing.isEmpty) return null;

    final env = existing['env'] as Map<String, dynamic>? ?? {};

    return ConfigProfile(
      apiKey: env['ANTHROPIC_AUTH_TOKEN'] as String?,
      baseUrl: env['ANTHROPIC_BASE_URL'] as String?,
      sonnetModelId: env['ANTHROPIC_DEFAULT_SONNET_MODEL'] as String?,
      opusModelId: env['ANTHROPIC_DEFAULT_OPUS_MODEL'] as String?,
      haikuModelId: env['ANTHROPIC_DEFAULT_HAIKU_MODEL'] as String?,
      skipOnboarding: true,
    );
  }

  /// Merge new settings into existing settings, preserving unrelated keys.
  Map<String, dynamic> _mergeSettings(
    Map<String, dynamic> existing,
    Map<String, dynamic> newSettings,
  ) {
    final merged = Map<String, dynamic>.from(existing);

    // Merge env
    if (newSettings.containsKey('env')) {
      final existingEnv =
          Map<String, dynamic>.from(merged['env'] as Map? ?? {});
      final newEnv = newSettings['env'] as Map<String, dynamic>;

      // Only update keys that are present and non-empty in the new config
      for (final entry in newEnv.entries) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          existingEnv[entry.key] = entry.value;
        }
      }

      merged['env'] = existingEnv;
    }

    // Merge other top-level keys
    for (final entry in newSettings.entries) {
      if (entry.key != 'env') {
        merged[entry.key] = entry.value;
      }
    }

    return merged;
  }

  /// Back up the existing settings.json before overwriting.
  Future<void> backupExistingSettings() async {
    final file = File(settingsPath);
    if (await file.exists()) {
      final backupFile = File('$settingsPath.backup');
      await file.copy(backupFile.path);
    }
  }
}
