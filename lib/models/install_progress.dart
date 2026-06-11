/// The current stage of the installation process.
enum InstallStage {
  /// Not started
  idle,

  /// Checking npm registry accessibility
  checkingRegistry,

  /// Downloading the package from npm
  downloading,

  /// Installing dependencies
  installing,

  /// Verifying the installation
  verifying,

  /// Installation completed successfully
  completed,

  /// Installation failed
  failed,
}

/// Represents the current state of the Claude Code installation process.
class InstallProgress {
  /// Current installation stage
  final InstallStage stage;

  /// Progress percentage from 0.0 to 1.0 (estimated)
  final double percent;

  /// Human-readable status message
  final String message;

  /// Recent terminal output lines
  final List<String> outputLines;

  /// Error details if stage is [InstallStage.failed]
  final String? error;

  /// Installed version if stage is [InstallStage.completed]
  final String? installedVersion;

  const InstallProgress({
    this.stage = InstallStage.idle,
    this.percent = 0.0,
    this.message = '准备安装...',
    this.outputLines = const [],
    this.error,
    this.installedVersion,
  });

  /// Whether the installation is actively running
  bool get isRunning =>
      stage != InstallStage.idle &&
      stage != InstallStage.completed &&
      stage != InstallStage.failed;

  /// Whether the installation is complete
  bool get isComplete => stage == InstallStage.completed;

  /// Whether the installation has failed
  bool get isFailed => stage == InstallStage.failed;

  /// Copy with updated fields
  InstallProgress copyWith({
    InstallStage? stage,
    double? percent,
    String? message,
    List<String>? outputLines,
    String? error,
    String? installedVersion,
    bool clearError = false,
  }) {
    return InstallProgress(
      stage: stage ?? this.stage,
      percent: percent ?? this.percent,
      message: message ?? this.message,
      outputLines: outputLines ?? this.outputLines,
      error: clearError ? null : (error ?? this.error),
      installedVersion: installedVersion ?? this.installedVersion,
    );
  }
}
