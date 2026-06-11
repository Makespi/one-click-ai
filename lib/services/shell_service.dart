import 'dart:convert' show utf8;
import 'dart:io' show Directory, File, Platform, Process;

/// Cross-platform shell command execution service.
///
/// Wraps dart:io Process for running commands and detecting installed tools.
/// On Windows, uses `runInShell: true` to handle .cmd/.bat files (npm, node, etc).
class ShellService {
  /// Whether we're running on Windows — commands need shell wrapping.
  bool get _isWindows => Platform.isWindows;

  /// Extra PATH prefixes for macOS/Linux GUI apps (which don't inherit shell PATH).
  static List<String> get _extraPaths {
    final home = Platform.environment['HOME'] ?? '/home';
    return [
      '/opt/homebrew/bin',      // Homebrew on Apple Silicon
      '/usr/local/bin',          // Homebrew on Intel / manual installs
      '/opt/local/bin',          // MacPorts
      '$home/.local/bin',        // user-local installs
      '$home/.nvm/versions/node', // nvm (we'll scan subdirs)
    ];
  }

  /// Resolve the full path to a command, searching common locations.
  /// On macOS/Linux, GUI apps may have a restricted PATH.
  Future<String?> _resolveCommand(String command) async {
    // First try the standard `which`
    var result = await Process.run(
      _isWindows ? 'where' : 'which',
      [command],
      runInShell: _isWindows,
    );
    if (result.exitCode == 0 && (result.stdout as String).trim().isNotEmpty) {
      return (result.stdout as String).trim().split('\n').first.trim();
    }

    if (_isWindows) return null;

    // On macOS/Linux, manually check known install paths
    for (final dir in _extraPaths) {
      // Handle nvm-style dirs: scan subdirectories for node versions
      if (dir.endsWith('/node')) {
        final dirEntity = Directory(dir);
        if (dirEntity.existsSync()) {
          try {
            for (final entry in dirEntity.listSync()) {
              if (entry is Directory) {
                final subPath = '${entry.path}/bin/$command';
                if (File(subPath).existsSync()) return subPath;
              }
            }
          } catch (_) {}
        }
        continue;
      }
      final fullPath = '$dir/$command';
      if (File(fullPath).existsSync()) return fullPath;
    }

    return null;
  }

  /// Build environment with extended PATH for macOS/Linux.
  Map<String, String> get _extendedEnv {
    if (_isWindows) return Platform.environment;
    final env = Map<String, String>.from(Platform.environment);
    final currentPath = env['PATH'] ?? '';
    final extra = ['/opt/homebrew/bin', '/usr/local/bin', '/opt/local/bin']
        .where((d) => Directory(d).existsSync())
        .join(':');
    if (extra.isNotEmpty) {
      env['PATH'] = '$extra:$currentPath';
    }
    return env;
  }

  /// Run a shell command and return the result.
  Future<ShellResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      // On Windows, run through shell to handle .cmd/.bat files
      final result = _isWindows
          ? await Process.run(
              'cmd',
              ['/c', executable, ...arguments],
              workingDirectory: workingDirectory,
              runInShell: true,
            )
          : await Process.run(
              executable,
              arguments,
              workingDirectory: workingDirectory,
              environment: _extendedEnv,
            );
      return ShellResult(
        exitCode: result.exitCode,
        stdout: (result.stdout as String).trim(),
        stderr: (result.stderr as String).trim(),
      );
    } catch (e) {
      return ShellResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
      );
    }
  }

  /// Check if a command exists on the system PATH or known install locations.
  Future<bool> commandExists(String command) async {
    if (_isWindows) {
      // On Windows, try `where` first; also try running `command --version`
      final whereResult = await run('where', [command]);
      if (whereResult.exitCode == 0 && whereResult.stdout.isNotEmpty) {
        return true;
      }
      // Fallback: try running the command directly
      final versionResult = await run('cmd', ['/c', command, '--version']);
      if (versionResult.exitCode == 0) return true;
      // Also try with .cmd extension
      final cmdResult = await run('cmd', ['/c', '$command.cmd', '--version']);
      return cmdResult.exitCode == 0;
    }
    // macOS/Linux: resolve full path including Homebrew locations
    final resolved = await _resolveCommand(command);
    return resolved != null;
  }

  /// Get the version string of an installed command.
  /// Runs `<command> --version` and returns the output.
  Future<String?> getCommandVersion(String command) async {
    // Resolve the full path first (handles Homebrew, etc.)
    final resolved = await _resolveCommand(command);
    final exec = resolved ?? command;

    // Try --version first
    var result = await _runVersionCommand(exec, '--version');
    if (result.exitCode != 0) {
      // Try -v as fallback
      result = await _runVersionCommand(exec, '-v');
    }
    if (result.exitCode != 0) {
      return null;
    }

    // Some tools write version to stderr
    final output = result.stdout.isNotEmpty ? result.stdout : result.stderr;

    // Extract version number (e.g., "v20.11.0" → "20.11.0", "10.8.2" → "10.8.2")
    final versionRegex = RegExp(r'(\d+\.\d+\.\d+)');
    final match = versionRegex.firstMatch(output);
    if (match != null) {
      return match.group(1);
    }
    // If no match, return the first line of output
    final firstLine = output.split('\n').first.trim();
    return firstLine.isNotEmpty ? firstLine : null;
  }

  Future<ShellResult> _runVersionCommand(String command, String flag) async {
    if (_isWindows) {
      return await Process.run(
        'cmd',
        ['/c', command, flag],
        runInShell: true,
      ).then((r) => ShellResult(
            exitCode: r.exitCode,
            stdout: (r.stdout as String).trim(),
            stderr: (r.stderr as String).trim(),
          )).catchError((_) => const ShellResult(
            exitCode: -1,
            stdout: '',
            stderr: '',
          ));
    }
    return await run(command, [flag]);
  }

  /// Run a command with streaming output.
  Future<ShellResult> runStreaming(
    String executable,
    List<String> arguments, {
    required void Function(String line) onStdout,
    void Function(String line)? onStderr,
    String? workingDirectory,
  }) async {
    try {
      // On Windows, wrap through cmd /c
      final processArgs = _isWindows
          ? ['/c', executable, ...arguments]
          : arguments;
      final processExec = _isWindows ? 'cmd' : executable;

      final process = await Process.start(
        processExec,
        processArgs,
        workingDirectory: workingDirectory,
        runInShell: _isWindows,
        environment: _isWindows ? null : _extendedEnv,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          final trimmed = line.trimRight();
          if (trimmed.isNotEmpty) {
            stdoutBuffer.writeln(trimmed);
            onStdout(trimmed);
          }
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          final trimmed = line.trimRight();
          if (trimmed.isNotEmpty) {
            stderrBuffer.writeln(trimmed);
            onStderr?.call(trimmed);
          }
        }
      });

      final exitCode = await process.exitCode;

      return ShellResult(
        exitCode: exitCode,
        stdout: stdoutBuffer.toString().trim(),
        stderr: stderrBuffer.toString().trim(),
      );
    } catch (e) {
      return ShellResult(
        exitCode: -1,
        stdout: '',
        stderr: e.toString(),
      );
    }
  }
}

/// Result of a shell command execution.
class ShellResult {
  final int exitCode;
  final String stdout;
  final String stderr;

  const ShellResult({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });

  bool get isSuccess => exitCode == 0;
  bool get isFailure => exitCode != 0;
}
