import 'dart:io' show Platform;

import '../models/platform_info.dart';
import '../models/prerequisite_result.dart';
import 'shell_service.dart';

/// Service to check and install system prerequisites (Node.js, npm, Git).
class PrerequisiteService {
  final ShellService _shell = ShellService();
  final PackageManager? _packageManager;

  PrerequisiteService({PackageManager? packageManager})
      : _packageManager = packageManager;

  /// Minimum required Node.js version
  static const minNodeVersion = '18.0.0';

  /// Minimum required npm version
  static const minNpmVersion = '9.0.0';

  /// Minimum required Git version
  static const minGitVersion = '2.0.0';

  /// Check if Node.js is installed and meets the minimum version.
  Future<PrerequisiteResult> checkNodeJs() async {
    const name = 'Node.js';

    final exists = await _shell.commandExists('node');
    if (!exists) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.missing,
        minVersion: minNodeVersion,
        installHint: getInstallInstructions(name),
      );
    }

    final version = await _shell.getCommandVersion('node');
    if (version == null) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.error,
        errorMessage: '无法获取版本信息',
      );
    }

    if (_compareVersions(version, minNodeVersion) < 0) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.outdated,
        version: version,
        minVersion: minNodeVersion,
        installHint: getInstallInstructions(name),
      );
    }

    return PrerequisiteResult(
      name: name,
      status: PrerequisiteStatus.installed,
      version: version,
      minVersion: minNodeVersion,
    );
  }

  /// Check if npm is installed and meets the minimum version.
  Future<PrerequisiteResult> checkNpm() async {
    const name = 'npm';

    final exists = await _shell.commandExists('npm');
    if (!exists) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.missing,
        minVersion: minNpmVersion,
        installHint: 'npm 通常随 Node.js 一起安装。请先安装 Node.js。',
      );
    }

    final version = await _shell.getCommandVersion('npm');
    if (version == null) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.error,
        errorMessage: '无法获取版本信息',
      );
    }

    if (_compareVersions(version, minNpmVersion) < 0) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.outdated,
        version: version,
        minVersion: minNpmVersion,
        installHint: '请更新 Node.js 到最新 LTS 版本以获取最新 npm。',
      );
    }

    return PrerequisiteResult(
      name: name,
      status: PrerequisiteStatus.installed,
      version: version,
      minVersion: minNpmVersion,
    );
  }

  /// Check if Git is installed and meets the minimum version.
  Future<PrerequisiteResult> checkGit() async {
    const name = 'Git';

    final exists = await _shell.commandExists('git');
    if (!exists) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.missing,
        minVersion: minGitVersion,
        installHint: getInstallInstructions(name),
      );
    }

    final version = await _shell.getCommandVersion('git');
    if (version == null) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.error,
        errorMessage: '无法获取版本信息',
      );
    }

    if (_compareVersions(version, minGitVersion) < 0) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.outdated,
        version: version,
        minVersion: minGitVersion,
        installHint: getInstallInstructions(name),
      );
    }

    return PrerequisiteResult(
      name: name,
      status: PrerequisiteStatus.installed,
      version: version,
      minVersion: minGitVersion,
    );
  }

  // ─── Auto-install methods ───────────────────────────────────────

  /// Whether auto-install is available (a package manager was detected).
  bool get canAutoInstall => _packageManager != null;

  /// Get the detected package manager, if any.
  PackageManager? get packageManager => _packageManager;

  /// Install a list of packages using the detected package manager.
  /// Returns a stream of output lines for real-time display.
  Future<AutoInstallResult> installPackages({
    required List<String> packages,
    required void Function(String line) onOutput,
  }) async {
    if (_packageManager == null) {
      return AutoInstallResult(
        success: false,
        error: '未检测到可用的包管理器',
      );
    }

    final command = _packageManager.installCommand(packages);
    if (command.isEmpty) {
      return AutoInstallResult(
        success: false,
        error: '无法生成安装命令',
      );
    }

    try {
      // Split command into executable and arguments
      final parts = command.split(' ');
      final executable = parts.first;
      final arguments = parts.sublist(1);

      final result = await _shell.runStreaming(
        executable,
        arguments,
        onStdout: onOutput,
        onStderr: onOutput,
      );

      return AutoInstallResult(
        success: result.isSuccess,
        error: result.isSuccess ? null : result.stderr,
      );
    } catch (e) {
      return AutoInstallResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Install Node.js automatically using the system package manager.
  Future<AutoInstallResult> installNodeJs({
    required void Function(String line) onOutput,
  }) async {
    final cmd = _packageManager!.installCommand(['node']);
    onOutput('\$ $cmd');
    onOutput('');

    final result = await installPackages(
      packages: ['node'],
      onOutput: onOutput,
    );

    // On Linux with apt, the package is usually named 'nodejs' not 'node'
    if (!result.success && _packageManager.id == 'apt') {
      onOutput('');
      onOutput('尝试 nodejs 包名...');
      return installPackages(
        packages: ['nodejs', 'npm'],
        onOutput: onOutput,
      );
    }

    return result;
  }

  /// Install Git automatically using the system package manager.
  Future<AutoInstallResult> installGit({
    required void Function(String line) onOutput,
  }) async {
    final cmd = _packageManager!.installCommand(['git']);
    onOutput('\$ $cmd');
    onOutput('');

    return installPackages(
      packages: ['git'],
      onOutput: onOutput,
    );
  }

  /// Install all missing prerequisites in sequence.
  Future<bool> installAllMissing({
    required List<String> missingDepNames,
    required void Function(String depName, String line) onOutput,
    required void Function(String depName, bool success) onComplete,
  }) async {
    for (final depName in missingDepNames) {
      AutoInstallResult result;
      switch (depName) {
        case 'Node.js':
          result = await installNodeJs(
            onOutput: (line) => onOutput(depName, line),
          );
          break;
        case 'Git':
          result = await installGit(
            onOutput: (line) => onOutput(depName, line),
          );
          break;
        default:
          onOutput(depName, '不支持的自动安装');
          onComplete(depName, false);
          continue;
      }
      onComplete(depName, result.success);
      if (!result.success) return false;
    }
    return true;
  }

  // ─── Helper methods ─────────────────────────────────────────────

  /// Get platform-specific install instructions for a prerequisite.
  String getInstallInstructions(String name) {
    // If we have a package manager, show the auto-install command
    if (_packageManager != null) {
      switch (name) {
        case 'Node.js':
          return _packageManager.installCommand(['node']);
        case 'Git':
          return _packageManager.installCommand(['git']);
      }
    }

    // Fallback to generic instructions
    switch (name) {
      case 'Node.js':
        if (Platform.isMacOS) {
          return 'brew install node';
        } else if (Platform.isWindows) {
          return '请从 https://nodejs.org 下载并安装 Node.js LTS 版本';
        } else {
          return '请使用包管理器安装：\n'
              'Ubuntu/Debian: sudo apt install nodejs npm\n'
              'Fedora: sudo dnf install nodejs npm\n'
              'Arch: sudo pacman -S nodejs npm\n'
              '或访问 https://nodejs.org';
        }
      case 'Git':
        if (Platform.isMacOS) {
          return 'brew install git 或 xcode-select --install';
        } else if (Platform.isWindows) {
          return '请从 https://git-scm.com 下载并安装 Git for Windows';
        } else {
          return '请使用包管理器安装：\n'
              'Ubuntu/Debian: sudo apt install git\n'
              'Fedora: sudo dnf install git\n'
              'Arch: sudo pacman -S git';
        }
      default:
        return '请手动安装 $name';
    }
  }

  /// Compare two semantic version strings.
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map(int.tryParse).toList();
    final parts2 = v2.split('.').map(int.tryParse).toList();

    for (var i = 0; i < 3; i++) {
      final p1 = i < parts1.length ? (parts1[i] ?? 0) : 0;
      final p2 = i < parts2.length ? (parts2[i] ?? 0) : 0;
      if (p1 < p2) return -1;
      if (p1 > p2) return 1;
    }
    return 0;
  }
}

/// Result of an auto-install operation.
class AutoInstallResult {
  final bool success;
  final String? error;

  const AutoInstallResult({required this.success, this.error});
}
