/// The status of a single prerequisite check.
enum PrerequisiteStatus {
  /// Check has not started yet
  pending,

  /// Check is currently running
  checking,

  /// Prerequisite is installed and meets requirements
  installed,

  /// Prerequisite is installed but version is too old
  outdated,

  /// Prerequisite is not installed
  missing,

  /// Check failed with an error
  error,
}

/// Result of checking a single prerequisite (Node.js, npm, Git, etc.)
class PrerequisiteResult {
  /// Display name, e.g. "Node.js", "npm", "Git"
  final String name;

  /// Current status of this prerequisite
  final PrerequisiteStatus status;

  /// Detected version string, e.g. "20.11.0"
  final String? version;

  /// Minimum required version, e.g. "18.0.0"
  final String? minVersion;

  /// Platform-specific install hint if the prerequisite is missing
  final String? installHint;

  /// Error message if the check failed
  final String? errorMessage;

  const PrerequisiteResult({
    required this.name,
    required this.status,
    this.version,
    this.minVersion,
    this.installHint,
    this.errorMessage,
  });

  /// Whether this prerequisite is ready (installed and meets min version)
  bool get isReady => status == PrerequisiteStatus.installed;

  /// Whether this prerequisite check has finished (success or failure)
  bool get isComplete =>
      status == PrerequisiteStatus.installed ||
      status == PrerequisiteStatus.outdated ||
      status == PrerequisiteStatus.missing ||
      status == PrerequisiteStatus.error;

  /// Human-readable status message
  String get statusMessage {
    switch (status) {
      case PrerequisiteStatus.pending:
        return '等待检测...';
      case PrerequisiteStatus.checking:
        return '正在检测...';
      case PrerequisiteStatus.installed:
        return '已安装 (v$version)';
      case PrerequisiteStatus.outdated:
        return '版本过旧 (v$version, 需要 >=v$minVersion)';
      case PrerequisiteStatus.missing:
        return '未安装';
      case PrerequisiteStatus.error:
        return '检测失败: ${errorMessage ?? "未知错误"}';
    }
  }

  /// Copy with updated fields
  PrerequisiteResult copyWith({
    String? name,
    PrerequisiteStatus? status,
    String? version,
    String? minVersion,
    String? installHint,
    String? errorMessage,
  }) {
    return PrerequisiteResult(
      name: name ?? this.name,
      status: status ?? this.status,
      version: version ?? this.version,
      minVersion: minVersion ?? this.minVersion,
      installHint: installHint ?? this.installHint,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
