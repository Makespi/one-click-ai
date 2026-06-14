import 'dart:io' show File, FileMode, Platform, Process;

import '../models/install_progress.dart';
import 'shell_service.dart';

/// Service to download and install Claude Code CLI.
class InstallService {
  final ShellService _shell = ShellService();

  /// Install Claude Code via npm, streaming progress updates.
  Future<InstallResult> installClaudeCode({
    required void Function(InstallProgress progress) onProgress,
  }) async {
    // Step 1: Check npm
    onProgress(InstallProgress(
      stage: InstallStage.checkingRegistry,
      percent: 0.05,
      message: '正在验证 npm 可用性...',
      outputLines: [r'$ npm --version'],
    ));

    final npmVersion = await _shell.getCommandVersion('npm');
    if (npmVersion == null) {
      throw Exception('npm 不可用，请先安装 Node.js');
    }

    onProgress(InstallProgress(
      stage: InstallStage.checkingRegistry,
      percent: 0.10,
      message: 'npm $npmVersion 就绪',
      outputLines: ['npm $npmVersion', ''],
    ));

    // Step 2: On macOS/Linux, configure npm prefix to avoid EACCES
    if (!Platform.isWindows) {
      await _ensureNpmPrefix(onProgress);
    }

    // Step 3: Install Claude Code
    onProgress(InstallProgress(
      stage: InstallStage.installing,
      percent: 0.20,
      message: '正在安装 @anthropic-ai/claude-code...',
      outputLines: [r'$ npm install -g @anthropic-ai/claude-code', ''],
    ));

    final outputLines = <String>[];
    double currentPercent = 0.20;

    try {
      final result = await _shell.runStreaming(
        'npm',
        ['install', '-g', '@anthropic-ai/claude-code'],
        onStdout: (line) {
          outputLines.add(line);

          // Estimate progress based on npm output patterns
          if (line.contains('added') || line.contains('packages')) {
            currentPercent = 0.80;
          }

          onProgress(InstallProgress(
            stage: InstallStage.installing,
            percent: currentPercent,
            message: '正在安装...',
            outputLines: List.from(outputLines),
          ));
        },
        onStderr: (line) {
          outputLines.add('[stderr] $line');

          // npm outputs download progress to stderr
          currentPercent += 0.02;
          if (currentPercent > 0.75) currentPercent = 0.75;

          onProgress(InstallProgress(
            stage: InstallStage.installing,
            percent: currentPercent,
            message: '正在下载...',
            outputLines: List.from(outputLines),
          ));
        },
      );

      if (!result.isSuccess) {
        // Check for common error patterns
        final errorText = result.stderr.isNotEmpty ? result.stderr : result.stdout;

        if (errorText.contains('EACCES') || errorText.contains('permission')) {
          throw Exception(
            '权限不足。已尝试自动配置 npm prefix，但仍失败。\n'
            '请手动运行以下命令后重试：\n'
            'mkdir -p ~/.npm-global\n'
            'npm config set prefix ~/.npm-global\n'
            'export PATH=~/.npm-global/bin:\$PATH',
          );
        }

        throw Exception('安装失败: $errorText');
      }
    } catch (e) {
      if (e is Exception) rethrow;

      onProgress(InstallProgress(
        stage: InstallStage.failed,
        percent: currentPercent,
        message: '安装失败',
        error: e.toString(),
        outputLines: outputLines,
      ));
      rethrow;
    }

    // Step 3: Verify installation
    onProgress(InstallProgress(
      stage: InstallStage.verifying,
      percent: 0.90,
      message: '正在验证安装...',
      outputLines: List.from(outputLines)
        ..add('')
        ..add(r'$ claude --version'),
    ));

    final claudeVersion = await _getClaudeVersion();
    if (claudeVersion != null) {
      outputLines.add('Claude Code $claudeVersion');

      onProgress(InstallProgress(
        stage: InstallStage.completed,
        percent: 1.0,
        message: '安装完成！Claude Code $claudeVersion',
        installedVersion: claudeVersion,
        outputLines: outputLines,
      ));

      return InstallResult(success: true, version: claudeVersion);
    } else {
      // Claude might be installed but not on PATH yet
      outputLines.add('警告: claude 命令未找到，可能需要重新打开终端');

      onProgress(InstallProgress(
        stage: InstallStage.completed,
        percent: 1.0,
        message: '安装完成，请重新打开终端后使用',
        outputLines: outputLines,
      ));

      return InstallResult(success: true, version: 'unknown');
    }
  }

  /// Configure npm to use a user-writable prefix to avoid EACCES errors.
  Future<void> _ensureNpmPrefix(
    void Function(InstallProgress progress) onProgress,
  ) async {
    // Check current prefix
    final prefixResult = await _shell.run('npm', ['config', 'get', 'prefix']);
    final currentPrefix = prefixResult.stdout.trim();

    // On macOS/Linux, check if global installs need sudo
    final needsSudo = currentPrefix.startsWith('/usr/') ||
        currentPrefix.startsWith('/opt/');

    if (needsSudo) {
      final home = Platform.environment['HOME'] ?? '/home';
      final userPrefix = '$home/.npm-global';

      onProgress(InstallProgress(
        stage: InstallStage.checkingRegistry,
        percent: 0.12,
        message: '配置 npm 到用户目录 (避免权限问题)...',
        outputLines: [r'$ npm config set prefix ~/.npm-global'],
      ));

      await _shell.run('npm', ['config', 'set', 'prefix', userPrefix]);

      // Ensure the bin directory is on PATH via .zshrc or .bash_profile
      final binPath = '$userPrefix/bin';
      await _updateShellRc(binPath);

      onProgress(InstallProgress(
        stage: InstallStage.checkingRegistry,
        percent: 0.15,
        message: 'npm prefix 已配置到 $userPrefix',
        outputLines: ['npm prefix → $userPrefix', ''],
      ));
    }
  }

  /// Append the npm global bin path to shell RC files.
  Future<void> _updateShellRc(String binPath) async {
    final home = Platform.environment['HOME'] ?? '/home';
    final pathLine = 'export PATH="$binPath:\$PATH"';

    for (final rcFile in ['$home/.zshrc', '$home/.bash_profile', '$home/.bashrc', '$home/.profile']) {
      try {
        final file = File(rcFile);
        if (await file.exists()) {
          final content = await file.readAsString();
          if (!content.contains(binPath)) {
            await file.writeAsString('$content\n# Added by One Click AI\n$pathLine\n',
                mode: FileMode.append);
          }
          return; // Updated the first existing rc file
        }
      } catch (_) {}
    }

    // If no rc file exists, create .zshrc
    try {
      final zshrc = File('$home/.zshrc');
      await zshrc.writeAsString(
        '# Added by One Click AI\n$pathLine\n',
        mode: FileMode.append,
      );
    } catch (_) {}
  }

  /// Check if Claude Code is already installed.
  Future<bool> isClaudeCodeInstalled() async {
    return _shell.commandExists('claude');
  }

  /// Uninstall Claude Code via npm.
  Future<UninstallResult> uninstallClaudeCode({
    required void Function(String line) onOutput,
  }) async {
    onOutput(r'$ npm uninstall -g @anthropic-ai/claude-code');
    onOutput('');

    try {
      var result = await _shell.runStreaming(
        'npm',
        ['uninstall', '-g', '@anthropic-ai/claude-code'],
        onStdout: onOutput,
        onStderr: onOutput,
      );

      if (!result.isSuccess) {
        final errorText = result.stderr.isNotEmpty ? result.stderr : result.stdout;

        // Permission error — try with admin privileges
        if (errorText.contains('EACCES') || errorText.contains('EPERM')) {
          onOutput('');
          onOutput('权限不足，尝试提权卸载...');

          if (Platform.isMacOS) {
            // macOS: use osascript admin dialog
            onOutput(r'$ osascript -e ''do shell script "npm uninstall -g @anthropic-ai/claude-code" with administrator privileges''');
            onOutput('系统将弹出密码输入框...');
            final sudoResult = await _shell.runStreaming(
              'osascript',
              ['-e',
               'do shell script "npm uninstall -g @anthropic-ai/claude-code" with administrator privileges'],
              onStdout: onOutput,
              onStderr: onOutput,
            );
            if (sudoResult.isSuccess) {
              onOutput('');
              onOutput('✓ Claude Code 已卸载');
              return const UninstallResult(success: true);
            }
          }

          // Also try --force as fallback
          onOutput('');
          onOutput('尝试强制卸载...');
          onOutput(r'$ npm uninstall -g --force @anthropic-ai/claude-code');
          result = await _shell.runStreaming(
            'npm',
            ['uninstall', '-g', '--force', '@anthropic-ai/claude-code'],
            onStdout: onOutput,
            onStderr: onOutput,
          );
        }

        if (!result.isSuccess) {
          final err = result.stderr.isNotEmpty ? result.stderr : result.stdout;
          return UninstallResult(
            success: false,
            error: '卸载失败。请手动运行:\n'
                'sudo npm uninstall -g @anthropic-ai/claude-code\n\n'
                '错误: $err',
          );
        }
      }

      onOutput('');
      onOutput('✓ Claude Code 已卸载');
      return UninstallResult(success: true);
    } catch (e) {
      return UninstallResult(success: false, error: e.toString());
    }
  }

  /// Verify that `claude` command works after installation.
  Future<bool> verifyInstallation() async {
    return _shell.commandExists('claude');
  }

  /// Get the installed Claude Code version.
  Future<String?> _getClaudeVersion() async {
    return _shell.getCommandVersion('claude');
  }
}

/// Result of the Claude Code installation.
class InstallResult {
  final bool success;
  final String? version;
  final String? error;

  const InstallResult({
    required this.success,
    this.version,
    this.error,
  });
}

/// Result of uninstalling Claude Code.
class UninstallResult {
  final bool success;
  final String? error;

  const UninstallResult({required this.success, this.error});
}

/// Open a terminal and launch Claude Code.
Future<void> launchClaudeInTerminal() async {
  final shell = ShellService();
  if (Platform.isMacOS) {
    await shell.run('osascript', [
      '-e',
      'tell application "Terminal" to activate',
      '-e',
      'tell application "Terminal" to do script "claude"',
    ]);
  } else if (Platform.isWindows) {
    // Open a new visible cmd window running claude
    await Process.run('cmd',
        ['/c', 'start', 'cmd', '/k', 'claude'],
        runInShell: true);
  } else {
    // Linux: try common terminals
    for (final term in ['gnome-terminal', 'konsole', 'xterm']) {
      final exists = await shell.commandExists(term);
      if (exists) {
        await Process.start(term, ['-e', 'bash -c "claude; exec bash"']);
        break;
      }
    }
  }
}
