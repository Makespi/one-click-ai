import 'package:flutter/material.dart';
import '../models/install_progress.dart';
import '../services/install_service.dart';

class InstallProvider extends ChangeNotifier {
  final InstallService _service = InstallService();

  InstallProgress _progress = const InstallProgress();
  bool _isInstalling = false;

  InstallProgress get progress => _progress;
  bool get isInstalling => _isInstalling;

  Future<void> startInstall() async {
    _isInstalling = true;
    _progress = const InstallProgress();
    notifyListeners();

    try {
      await _service.installClaudeCode(
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
      );
    } catch (e) {
      _progress = _progress.copyWith(
        stage: InstallStage.failed,
        message: '安装失败',
        error: e.toString(),
      );
    }

    _isInstalling = false;
    notifyListeners();
  }

  Future<bool> verifyInstallation() async {
    return _service.verifyInstallation();
  }
}
