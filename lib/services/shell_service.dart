import 'dart:convert' show utf8;
import 'dart:io' show Platform, Process;

/// Cross-platform shell command execution service.
///
/// Wraps dart:io Process for running commands and detecting installed tools.
class ShellService {
  /// Run a shell command and return the result.
  Future<ShellResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
  }) async {
    try {
      final result = await Process.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
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

  /// Check if a command exists on the system PATH.
  Future<bool> commandExists(String command) async {
    final checkCmd = Platform.isWindows ? 'where' : 'which';
    final result = await run(checkCmd, [command]);
    return result.exitCode == 0 && result.stdout.isNotEmpty;
  }

  /// Get the version string of an installed command.
  /// Runs `<command> --version` and returns the output.
  Future<String?> getCommandVersion(String command) async {
    final result = await run(command, ['--version']);
    if (result.exitCode == 0) {
      // Some tools write version to stderr (like node --version on some platforms)
      final output = result.stdout.isNotEmpty ? result.stdout : result.stderr;
      // Extract version number (e.g., "v20.11.0" → "20.11.0")
      final versionRegex = RegExp(r'(\d+\.\d+\.\d+)');
      final match = versionRegex.firstMatch(output);
      if (match != null) {
        return match.group(1);
      }
      return output;
    }
    return null;
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
      final process = await Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
      );

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.isNotEmpty) {
            stdoutBuffer.writeln(line);
            onStdout(line);
          }
        }
      });

      process.stderr.transform(utf8.decoder).listen((data) {
        for (final line in data.split('\n')) {
          if (line.isNotEmpty) {
            stderrBuffer.writeln(line);
            onStderr?.call(line);
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
