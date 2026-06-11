import 'package:flutter/material.dart';
import '../models/config_profile.dart';
import '../services/config_service.dart';

/// Available API provider types for the configuration form.
enum ApiProviderType {
  anthropic,
  custom,
  deepseek,
}

class ConfigProvider extends ChangeNotifier {
  final ConfigService _service = ConfigService();

  ConfigProfile _profile = ConfigProfile.empty();
  ApiProviderType _providerType = ApiProviderType.deepseek;
  bool _isWriting = false;
  bool _isWritten = false;
  String? _writeError;
  bool _existingConfigLoaded = false;
  bool _hasExistingConfig = false;

  ConfigProfile get profile => _profile;
  ApiProviderType get providerType => _providerType;
  bool get isWriting => _isWriting;
  bool get isWritten => _isWritten;
  String? get writeError => _writeError;
  bool get existingConfigLoaded => _existingConfigLoaded;
  bool get hasExistingConfig => _hasExistingConfig;

  /// Whether the existing config is complete enough to skip the configure step.
  bool get isAlreadyConfigured =>
      _hasExistingConfig &&
      _profile.apiKey != null &&
      _profile.apiKey!.isNotEmpty;

  /// Load existing settings.json to pre-fill the form.
  Future<void> loadExistingConfig() async {
    if (_existingConfigLoaded) return;

    final existing = await _service.readSettings();
    if (existing != null) {
      _hasExistingConfig = true;
      _profile = existing;

      // Detect provider type from base URL
      if (existing.baseUrl != null &&
          existing.baseUrl!.contains('deepseek')) {
        _providerType = ApiProviderType.deepseek;
      } else if (existing.baseUrl != null) {
        _providerType = ApiProviderType.custom;
      } else {
        _providerType = ApiProviderType.anthropic;
      }
    }

    _existingConfigLoaded = true;
    notifyListeners();
  }

  void setApiKey(String key) {
    _profile = _profile.copyWith(apiKey: key);
    notifyListeners();
  }

  void setBaseUrl(String url) {
    _profile = _profile.copyWith(baseUrl: url);
    notifyListeners();
  }

  void setProviderType(ApiProviderType type) {
    _providerType = type;
    switch (type) {
      case ApiProviderType.anthropic:
        _profile = ConfigProfile.anthropicOfficial(
          apiKey: _profile.apiKey ?? '',
        );
        break;
      case ApiProviderType.custom:
        _profile = _profile.copyWith();
        break;
      case ApiProviderType.deepseek:
        _profile = ConfigProfile.deepSeek(
          apiKey: _profile.apiKey ?? '',
        );
        break;
    }
    notifyListeners();
  }

  void setSonnetModelId(String id) {
    _profile = _profile.copyWith(sonnetModelId: id);
    notifyListeners();
  }

  void setOpusModelId(String id) {
    _profile = _profile.copyWith(opusModelId: id);
    notifyListeners();
  }

  void setHaikuModelId(String id) {
    _profile = _profile.copyWith(haikuModelId: id);
    notifyListeners();
  }

  Future<void> writeConfig() async {
    if (_isWritten) return; // already written

    _isWriting = true;
    _writeError = null;
    notifyListeners();

    try {
      await _service.backupExistingSettings();
      await _service.writeSettings(_profile);
      await _service.writeOnboardingBypass();
      _isWritten = true;
    } catch (e) {
      _writeError = e.toString();
    }

    _isWriting = false;
    notifyListeners();
  }
}
