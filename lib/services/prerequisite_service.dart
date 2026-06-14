import 'dart:io' show File, FileMode, Platform, Process;

import '../models/platform_info.dart';
import '../models/prerequisite_result.dart';
import 'shell_service.dart';

/// Service to check and install system prerequisites (Node.js, npm, Git).
class PrerequisiteService {
  final ShellService _shell = ShellService();
  final PackageManager? _packageManager;
  final List<PackageManager> _allPackageManagers;

  PrerequisiteService({
    PackageManager? packageManager,
    List<PackageManager> allPackageManagers = const [],
  })  : _packageManager = packageManager,
        _allPackageManagers = allPackageManagers;

  /// Minimum required Node.js version
  static const minNodeVersion = '18.0.0';

  /// Minimum required npm version
  static const minNpmVersion = '9.0.0';

  /// Minimum required Git version
  static const minGitVersion = '2.0.0';

  /// Check if Node.js is installed and meets the minimum version.
  Future<PrerequisiteResult> checkNodeJs() async {
    const name = 'Node.js';

    var exists = await _shell.commandExists('node');

    // On Windows, check common install paths (node may not be on PATH yet)
    if (!exists && Platform.isWindows) {
      for (final path in _windowsNodePaths()) {
        if (File(path).existsSync()) {
          exists = true;
          _addBinToUserPath(path);
          break;
        }
      }
    }

    if (!exists) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.missing,
        minVersion: minNodeVersion,
        installHint: getInstallInstructions(name),
      );
    }

    // Get version via common paths on Windows if not on PATH
    final version = Platform.isWindows && !await _shell.commandExists('node')
        ? await _exeVersionWindows('node.exe', _windowsNodePaths())
        : await _shell.getCommandVersion('node');

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

  /// Common Git install paths on Windows.
  List<String> _windowsGitPaths() {
    final home = Platform.environment['USERPROFILE'] ?? r'C:\Users';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? r'C:\Users';
    return [
      r'C:\Program Files\Git\bin\git.exe',
      r'C:\Program Files (x86)\Git\bin\git.exe',
      r'C:\Program Files\Git\cmd\git.exe',
      r'C:\Program Files (x86)\Git\cmd\git.exe',
      '$localAppData\\Programs\\Git\\bin\\git.exe',
      '$home\\scoop\\apps\\git\\current\\bin\\git.exe',
    ];
  }

  /// Common Node.js install paths on Windows.
  List<String> _windowsNodePaths() {
    final home = Platform.environment['USERPROFILE'] ?? r'C:\Users';
    return [
      r'C:\Program Files\nodejs\node.exe',
      r'C:\Program Files (x86)\nodejs\node.exe',
      '$home\\scoop\\apps\\nodejs\\current\\node.exe',
    ];
  }

  /// Add a directory to the current process PATH (Windows only).
  /// Add a bin directory to the Windows user PATH (via PowerShell).
  void _addBinToUserPath(String exePath) {
    if (!Platform.isWindows) return;
    try {
      final binDir = exePath.substring(0, exePath.lastIndexOf('\\'));
      final currentUserPath = Platform.environment['PATH'] ?? '';
      if (!currentUserPath.contains(binDir)) {
        // Use PowerShell to safely append to user PATH
        final psCmd = '[Environment]::SetEnvironmentVariable(\'PATH\', '
            '[Environment]::GetEnvironmentVariable(\'PATH\', \'User\') + \';$binDir\', \'User\')';
        Process.runSync('powershell', ['-Command', psCmd], runInShell: true);
      }
    } catch (_) {}
  }

  /// Get version from a Windows exe at known paths.
  Future<String?> _exeVersionWindows(String exeName, List<String> paths) async {
    for (final path in paths) {
      if (File(path).existsSync()) {
        try {
          final result = await Process.run(path, ['--version'], runInShell: true)
              .timeout(const Duration(seconds: 10));
          if (result.exitCode == 0) {
            final output = (result.stdout as String).trim();
            final match = RegExp(r'(\d+\.\d+\.\d+)').firstMatch(output);
            return match?.group(1) ?? output;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  /// Check if npm is installed and meets the minimum version.
  Future<PrerequisiteResult> checkNpm() async {
    const name = 'npm';

    var exists = await _shell.commandExists('npm');

    // On Windows, check common install paths (npm may not be on PATH yet)
    if (!exists && Platform.isWindows) {
      for (final dir in _windowsNodePaths()) {
        // Node is at C:\...\node.exe; npm is C:\...\npm.cmd
        final npmPath = '${dir.substring(0, dir.lastIndexOf('\\') + 1)}npm.cmd';
        if (File(npmPath).existsSync()) {
          exists = true;
          break;
        }
      }
    }

    if (!exists) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.missing,
        minVersion: minNpmVersion,
        installHint: 'npm 通常随 Node.js 一起安装。请先安装 Node.js。',
      );
    }

    // Get version via common paths on Windows if not on PATH
    final version = Platform.isWindows && !await _shell.commandExists('npm')
        ? await _exeVersionWindows('npm.cmd', _windowsNodePaths()
            .map((p) => '${p.substring(0, p.lastIndexOf('\\') + 1)}npm.cmd')
            .toList())
        : await _shell.getCommandVersion('npm');

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

    var exists = await _shell.commandExists('git');

    // On Windows, check common install paths (git may not be on PATH yet)
    if (!exists && Platform.isWindows) {
      for (final path in _windowsGitPaths()) {
        if (File(path).existsSync()) {
          exists = true;
          // Auto-add to user PATH
          _addBinToUserPath(path);
          break;
        }
      }
    }

    if (!exists) {
      return PrerequisiteResult(
        name: name,
        status: PrerequisiteStatus.missing,
        minVersion: minGitVersion,
        installHint: getInstallInstructions(name),
      );
    }

    // Get version via common paths on Windows if not on PATH
    final version = Platform.isWindows && !await _shell.commandExists('git')
        ? await _exeVersionWindows('git.exe', _windowsGitPaths())
        : await _shell.getCommandVersion('git');

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

  /// Whether auto-install is available (at least one package manager detected).
  bool get canAutoInstall => _allPackageManagers.isNotEmpty;

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

  /// Install Node.js — tries all available package managers in sequence.
  Future<AutoInstallResult> installNodeJs({
    required void Function(String line) onOutput,
  }) async {
    for (var i = 0; i < _allPackageManagers.length; i++) {
      final pm = _allPackageManagers[i];
      final hasNext = i < _allPackageManagers.length - 1;
      final cmd = pm.installCommand(['node']);
      onOutput('${pm.displayName}: \$ $cmd');
      onOutput('');

      final result = await _installWithPm(pm, ['node'], onOutput);
      if (result.success) return result;

      if (pm.id == 'apt') {
        onOutput('');
        onOutput('尝试 nodejs 包名...');
        final aptResult = await _installWithPm(pm, ['nodejs', 'npm'], onOutput);
        if (aptResult.success) return aptResult;
      }

      if (hasNext) {
        onOutput('${pm.displayName} 失败，尝试 ${_allPackageManagers[i + 1].displayName}...');
      } else {
        onOutput('${pm.displayName} 安装失败');
      }
      onOutput('');
    }

    // All package managers failed — try direct download
    onOutput('');
    onOutput('包管理器均失败，尝试直接下载安装...');
    return _installNodeDirectly(onOutput);
  }

  /// Install Git — tries all available package managers in sequence.
  Future<AutoInstallResult> installGit({
    required void Function(String line) onOutput,
  }) async {
    for (var i = 0; i < _allPackageManagers.length; i++) {
      final pm = _allPackageManagers[i];
      final hasNext = i < _allPackageManagers.length - 1;
      final cmd = pm.installCommand(['git']);
      onOutput('${pm.displayName}: \$ $cmd');
      onOutput('');

      final result = await _installWithPm(pm, ['git'], onOutput);
      if (result.success) return result;

      if (hasNext) {
        onOutput('${pm.displayName} 失败，尝试 ${_allPackageManagers[i + 1].displayName}...');
      } else {
        onOutput('${pm.displayName} 安装失败');
      }
      onOutput('');
    }

    // All package managers failed — try direct download
    onOutput('');
    onOutput('包管理器均失败，尝试直接下载安装...');
    return _installGitDirectly(onOutput);
  }

  /// Download and install Node.js directly from nodejs.org.
  Future<AutoInstallResult> _installNodeDirectly(
    void Function(String line) onOutput,
  ) async {
    final arch = _detectArch();
    if (Platform.isMacOS) {
      final url = arch == 'arm64'
          ? 'https://nodejs.org/dist/v20.18.0/node-v20.18.0.pkg'
          : 'https://nodejs.org/dist/v20.18.0/node-v20.18.0.pkg';
      return _macOSInstallPkg(url, 'Node.js', onOutput);
    } else if (Platform.isWindows) {
      final url = arch == 'arm64'
          ? 'https://nodejs.org/dist/v20.18.0/node-v20.18.0-arm64.msi'
          : 'https://nodejs.org/dist/v20.18.0/node-v20.18.0-x64.msi';
      return _windowsInstallMsi(url, 'Node.js', onOutput);
    } else {
      final url = arch == 'arm64'
          ? 'https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-arm64.tar.xz'
          : 'https://nodejs.org/dist/v20.18.0/node-v20.18.0-linux-x64.tar.xz';
      return _linuxInstallTarball(url, 'Node.js', onOutput);
    }
  }

  String _detectArch() {
    try {
      final result = Process.runSync('uname', ['-m']);
      final output = (result.stdout as String).trim();
      if (output.contains('arm') || output.contains('aarch')) return 'arm64';
    } catch (_) {}
    return 'x64';
  }

  /// Download and install Git directly.
  Future<AutoInstallResult> _installGitDirectly(
    void Function(String line) onOutput,
  ) async {
    if (Platform.isMacOS) {
      // macOS: check if git is already available (usually bundled with Xcode CLT)
      final gitExists = await _shell.commandExists('git');
      if (gitExists) {
        onOutput('Git 已可用');
        return const AutoInstallResult(success: true);
      }
      onOutput('尝试安装 Xcode Command Line Tools (包含 Git)...');
      onOutput(r'$ xcode-select --install');
      await _shell.run('xcode-select', ['--install']);
      // Give it a moment and try again
      final recheck = await _shell.commandExists('git');
      return AutoInstallResult(
        success: recheck,
        error: recheck ? null : 'Git 安装可能需要手动完成',
      );
    } else if (Platform.isWindows) {
      final arch = _detectArch();
      final url = arch == 'arm64'
          ? 'https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.1/Git-2.47.0-64-bit.exe'
          : 'https://github.com/git-for-windows/git/releases/download/v2.47.0.windows.1/Git-2.47.0-64-bit.exe';
      return _windowsInstallExe(url, '/VERYSILENT /NORESTART', 'Git', onOutput);
    } else {
      // Linux: most distros have git available, try direct check
      final exists = await _shell.commandExists('git');
      if (exists) {
        onOutput('Git 已可用');
        return const AutoInstallResult(success: true);
      }
      return const AutoInstallResult(
        success: false,
        error: '请使用系统包管理器安装 Git，或访问 https://git-scm.com',
      );
    }
  }

  /// Download and run a macOS .pkg installer.
  Future<AutoInstallResult> _macOSInstallPkg(
    String url,
    String name,
    void Function(String line) onOutput,
  ) async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final pkgPath = '$home/Downloads/${name}_installer.pkg';

    onOutput('下载 $name...');
    onOutput('\$ curl -L -o $pkgPath $url');

    final dlResult = await _shell.runStreaming(
      'curl', ['-L', '-o', pkgPath, url, '--progress-bar'],
      onStdout: onOutput,
      onStderr: onOutput,
    );

    if (!dlResult.isSuccess) {
      return AutoInstallResult(success: false, error: '下载失败');
    }

    onOutput('');
    onOutput('安装 $name...');
    onOutput('\$ open $pkgPath');

    final installResult = await _shell.runStreaming(
      'open', ['-W', pkgPath],
      onStdout: onOutput,
      onStderr: onOutput,
    );


    // Cleanup
    try { File(pkgPath).deleteSync(); } catch (_) {}

    return AutoInstallResult(
      success: installResult.isSuccess,
      error: installResult.isSuccess ? null : installResult.stderr,
    );
  }

  /// Download and run a Windows .msi installer.
  Future<AutoInstallResult> _windowsInstallMsi(
    String url,
    String name,
    void Function(String line) onOutput,
  ) async {
    final tmp = Platform.environment['TEMP'] ?? r'C:\Windows\Temp';
    final msiPath = '$tmp\\${name}_installer.msi';

    onOutput('下载 $name...');
    onOutput('\$ curl -L -o $msiPath $url');

    final dlResult = await _shell.runStreaming(
      'curl', ['-L', '-o', msiPath, url, '--progress-bar'],
      onStdout: onOutput,
      onStderr: onOutput,
    );

    if (!dlResult.isSuccess) {
      return AutoInstallResult(success: false, error: '下载失败');
    }

    onOutput('');
    onOutput('安装 $name (静默)...');
    onOutput('\$ msiexec /i $msiPath /quiet /norestart');

    final installResult = await _shell.runStreaming(
      'msiexec', ['/i', msiPath, '/quiet', '/norestart'],
      onStdout: onOutput,
      onStderr: onOutput,
    );

    try { File(msiPath).deleteSync(); } catch (_) {}

    return AutoInstallResult(
      success: installResult.isSuccess,
      error: installResult.isSuccess ? null : installResult.stderr,
    );
  }

  /// Download and run a Windows .exe installer.
  Future<AutoInstallResult> _windowsInstallExe(
    String url,
    String silentArgs,
    String name,
    void Function(String line) onOutput,
  ) async {
    final tmp = Platform.environment['TEMP'] ?? r'C:\Windows\Temp';
    final exePath = '$tmp\\${name}_installer.exe';

    onOutput('下载 $name...');
    onOutput('\$ curl -L -o $exePath $url');

    final dlResult = await _shell.runStreaming(
      'curl', ['-L', '-o', exePath, url, '--progress-bar'],
      onStdout: onOutput,
      onStderr: onOutput,
    );

    if (!dlResult.isSuccess) {
      return AutoInstallResult(success: false, error: '下载失败');
    }

    onOutput('');
    onOutput('安装 $name (静默)...');
    onOutput('\$ $exePath $silentArgs');

    final parts = silentArgs.split(' ');
    final installResult = await _shell.runStreaming(
      exePath, parts,
      onStdout: onOutput,
      onStderr: onOutput,
    );

    try { File(exePath).deleteSync(); } catch (_) {}

    return AutoInstallResult(
      success: installResult.isSuccess,
      error: installResult.isSuccess ? null : installResult.stderr,
    );
  }

  /// Download and extract a Linux .tar.xz tarball.
  Future<AutoInstallResult> _linuxInstallTarball(
    String url,
    String name,
    void Function(String line) onOutput,
  ) async {
    final tmp = '/tmp/${name}_installer.tar.xz';

    onOutput('下载 $name...');
    onOutput('\$ curl -L -o $tmp $url');

    final dlResult = await _shell.runStreaming(
      'curl', ['-L', '-o', tmp, url, '--progress-bar'],
      onStdout: onOutput,
      onStderr: onOutput,
    );

    if (!dlResult.isSuccess) {
      return AutoInstallResult(success: false, error: '下载失败');
    }

    final home = Platform.environment['HOME'] ?? '/home';
    final installDir = '$home/.local';
    final binDir = '$installDir/bin';

    onOutput('');
    onOutput('解压并安装到 $installDir...');
    onOutput('\$ mkdir -p $installDir && tar -xJf $tmp -C $installDir --strip-components=1');

    await _shell.run('mkdir', ['-p', installDir]);
    final installResult = await _shell.runStreaming(
      'tar', ['-xJf', tmp, '-C', installDir, '--strip-components=1'],
      onStdout: onOutput,
      onStderr: onOutput,
    );

    if (installResult.isSuccess) {
      onOutput('');
      onOutput('已安装到 $installDir');
      onOutput('添加 PATH: export PATH=$binDir:\$PATH');

      // Update shell rc files to include the new PATH
      final pathLine = 'export PATH=$binDir:\$PATH';
      for (final rc in ['$home/.bashrc', '$home/.profile', '$home/.zshrc']) {
        try {
          final f = File(rc);
          if (await f.exists()) {
            final content = await f.readAsString();
            if (!content.contains(binDir)) {
              await f.writeAsString('$content\n# Node.js\n$pathLine\n',
                  mode: FileMode.append);
            }
          }
        } catch (_) {}
      }
    }

    try { File(tmp).deleteSync(); } catch (_) {}

    return AutoInstallResult(
      success: installResult.isSuccess,
      error: installResult.isSuccess ? null : installResult.stderr,
    );
  }

  /// Run install with a specific package manager.
  Future<AutoInstallResult> _installWithPm(
    PackageManager pm,
    List<String> packages,
    void Function(String line) onOutput,
  ) async {
    final command = pm.installCommand(packages);
    if (command.isEmpty) {
      return const AutoInstallResult(success: false, error: '无法生成安装命令');
    }

    try {
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
      return AutoInstallResult(success: false, error: e.toString());
    }
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
    // Show install command for the first available package manager
    if (_allPackageManagers.isNotEmpty) {
      final pm = _allPackageManagers.first;
      switch (name) {
        case 'Node.js':
          return '${pm.displayName}: ${pm.installCommand(['node'])}';
        case 'Git':
          return '${pm.displayName}: ${pm.installCommand(['git'])}';
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
