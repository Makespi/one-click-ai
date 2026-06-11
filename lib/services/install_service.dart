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

    // Step 2: Install Claude Code
    onProgress(InstallProgress(
      stage: InstallStage.installing,
      percent: 0.15,
      message: '正在安装 @anthropic-ai/claude-code...',
      outputLines: [r'$ npm install -g @anthropic-ai/claude-code', ''],
    ));

    final outputLines = <String>[];
    double currentPercent = 0.15;

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
            '权限不足。请尝试以下解决方案：\n'
            '1. macOS/Linux: 配置 npm prefix\n'
            '   npm config set prefix \'~/.npm-global\'\n'
            '2. Windows: 以管理员身份运行终端\n'
            '或重新运行安装程序。',
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

  /// Check if Claude Code is already installed.
  Future<bool> isClaudeCodeInstalled() async {
    return _shell.commandExists('claude');
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
