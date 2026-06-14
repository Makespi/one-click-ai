import 'package:flutter/material.dart';

import '../models/platform_info.dart';
import '../models/prerequisite_result.dart';
import '../services/prerequisite_service.dart';

/// Auto-install state for a specific prerequisite.
class DepInstallState {
  final bool isInstalling;
  final List<String> outputLines;
  final bool? success;
  final String? error;

  const DepInstallState({
    this.isInstalling = false,
    this.outputLines = const [],
    this.success,
    this.error,
  });

  DepInstallState copyWith({
    bool? isInstalling,
    List<String>? outputLines,
    bool? success,
    String? error,
    bool clearOutput = false,
    bool clearError = false,
  }) {
    return DepInstallState(
      isInstalling: isInstalling ?? this.isInstalling,
      outputLines: clearOutput ? [] : (outputLines ?? this.outputLines),
      success: success ?? this.success,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PrerequisiteProvider extends ChangeNotifier {
  late final PrerequisiteService _service;

  PrerequisiteProvider({required PlatformInfo platformInfo}) {
    _service = PrerequisiteService(
      packageManager: platformInfo.packageManager,
      allPackageManagers: platformInfo.allPackageManagers,
    );
  }

  List<PrerequisiteResult> _results = [];
  bool _isChecking = false;
  final Map<String, DepInstallState> _installStates = {};

  List<PrerequisiteResult> get results => _results;
  bool get isChecking => _isChecking;
  bool get allReady => _results.isNotEmpty && _results.every((r) => r.isReady);
  bool get canAutoInstall => _service.canAutoInstall;

  /// Get the install state for a specific prerequisite.
  DepInstallState getInstallState(String name) {
    return _installStates[name] ?? const DepInstallState();
  }

  /// Whether any dependency is currently being installed.
  bool get isAnyInstalling =>
      _installStates.values.any((s) => s.isInstalling);

  Future<void> checkAll() async {
    _isChecking = true;
    _results = [
      const PrerequisiteResult(
        name: 'Node.js',
        status: PrerequisiteStatus.pending,
        minVersion: '18.0.0',
      ),
      const PrerequisiteResult(
        name: 'npm',
        status: PrerequisiteStatus.pending,
        minVersion: '9.0.0',
      ),
      const PrerequisiteResult(
        name: 'Git',
        status: PrerequisiteStatus.pending,
        minVersion: '2.0.0',
      ),
    ];
    notifyListeners();

    await _checkPrerequisite(0, () => _service.checkNodeJs());
    await _checkPrerequisite(1, () => _service.checkNpm());
    await _checkPrerequisite(2, () => _service.checkGit());

    _isChecking = false;
    notifyListeners();
  }

  Future<void> _checkPrerequisite(
    int index,
    Future<PrerequisiteResult> Function() checkFn,
  ) async {
    _results[index] = _results[index].copyWith(
      status: PrerequisiteStatus.checking,
    );
    notifyListeners();

    try {
      _results[index] = await checkFn();
    } catch (e) {
      _results[index] = _results[index].copyWith(
        status: PrerequisiteStatus.error,
        errorMessage: e.toString(),
      );
    }
    notifyListeners();
  }

  /// Auto-install a missing prerequisite.
  Future<bool> installDependency(String name) async {
    _installStates[name] = const DepInstallState(isInstalling: true);
    notifyListeners();

    bool success = false;
    try {
      if (name == 'Node.js') {
        final result = await _service.installNodeJs(
          onOutput: (line) {
            _appendOutput(name, line);
          },
        );
        success = result.success;
      } else if (name == 'Git') {
        final result = await _service.installGit(
          onOutput: (line) {
            _appendOutput(name, line);
          },
        );
        success = result.success;
      }

      _installStates[name] = DepInstallState(
        isInstalling: false,
        outputLines: _installStates[name]?.outputLines ?? [],
        success: success,
        error: success ? null : '安装失败',
      );
    } catch (e) {
      _installStates[name] = DepInstallState(
        isInstalling: false,
        outputLines: _installStates[name]?.outputLines ?? [],
        success: false,
        error: e.toString(),
      );
    }

    notifyListeners();
    return success;
  }

  void _appendOutput(String name, String line) {
    final current = _installStates[name] ?? const DepInstallState();
    final lines = List<String>.from(current.outputLines)..add(line);
    _installStates[name] = current.copyWith(
      outputLines: lines,
      isInstalling: true,
    );
    notifyListeners();
  }

  /// Re-check a single dependency after install.
  /// On Windows, also checks common install paths since choco/winget
  /// may install to directories not immediately on PATH.
  Future<void> recheckDependency(String name) async {
    final index = _results.indexWhere((r) => r.name == name);
    if (index < 0) return;

    switch (name) {
      case 'Node.js':
        await _checkPrerequisite(index, () => _service.checkNodeJs());
        final npmIndex = _results.indexWhere((r) => r.name == 'npm');
        if (npmIndex >= 0) {
          await _checkPrerequisite(npmIndex, () => _service.checkNpm());
        }
        break;
      case 'npm':
        await _checkPrerequisite(index, () => _service.checkNpm());
        break;
      case 'Git':
        await _checkPrerequisite(index, () => _service.checkGit());
        break;
    }

    // If still not found, retry once more after a short delay
    // (package managers sometimes return before PATH is updated)
    if (!_results[index].isReady) {
      await Future.delayed(const Duration(seconds: 2));
      switch (name) {
        case 'Node.js':
          await _checkPrerequisite(index, () => _service.checkNodeJs());
          break;
        case 'Git':
          await _checkPrerequisite(index, () => _service.checkGit());
          break;
      }
    }

    if (_results[index].isReady) {
      _installStates.remove(name);
    }
    notifyListeners();
  }

  /// Get install instructions for a missing prerequisite.
  String getInstallInstructions(String name) {
    return _service.getInstallInstructions(name);
  }
}
