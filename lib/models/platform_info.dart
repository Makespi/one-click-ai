/// Detected package manager on the host system.
class PackageManager {
  /// Identifier: "brew", "apt", "dnf", "pacman", "winget", "choco"
  final String id;

  /// Display name: "Homebrew", "APT", "dnf", etc.
  final String displayName;

  /// Whether this package manager supports unattended (non-interactive) installs
  final bool supportsUnattended;

  const PackageManager({
    required this.id,
    required this.displayName,
    this.supportsUnattended = true,
  });

  /// Build an install command for a given list of packages.
  String installCommand(List<String> packages) {
    final pkgList = packages.join(' ');
    switch (id) {
      case 'brew':
        return 'brew install $pkgList';
      case 'apt':
        return 'sudo apt install -y $pkgList';
      case 'dnf':
        return 'sudo dnf install -y $pkgList';
      case 'pacman':
        return 'sudo pacman -S --noconfirm $pkgList';
      case 'winget':
        return 'winget install --accept-source-agreements --accept-package-agreements ${packages.map((p) => _wingetId(p)).join(' ')}';
      case 'choco':
        return 'choco install -y $pkgList';
      default:
        return '';
    }
  }

  String _wingetId(String name) {
    switch (name) {
      case 'node':
        return 'OpenJS.NodeJS.LTS';
      case 'git':
        return 'Git.Git';
      default:
        return name;
    }
  }
}

/// Represents the detected platform information of the host machine.
class PlatformInfo {
  /// Operating system name: "windows", "macos", or "linux"
  final String os;

  /// CPU architecture: "x86_64" or "arm64"
  final String architecture;

  /// Human-readable OS version string, e.g. "macOS 14.3"
  final String osVersion;

  /// Distribution name for Linux, e.g. "Ubuntu 22.04"
  final String? distro;

  /// Path to the user's home directory
  final String homeDir;

  /// Detected package manager (may be null if none found)
  final PackageManager? packageManager;

  /// Whether the current OS is macOS
  bool get isMacOS => os == 'macos';

  /// Whether the current OS is Windows
  bool get isWindows => os == 'windows';

  /// Whether the current OS is Linux
  bool get isLinux => os == 'linux';

  /// Whether a supported package manager is available for auto-install
  bool get hasPackageManager => packageManager != null;

  const PlatformInfo({
    required this.os,
    required this.architecture,
    required this.osVersion,
    this.distro,
    required this.homeDir,
    this.packageManager,
  });

  /// Returns the display name for the OS with icon indicator
  String get displayName {
    final distroPart = distro != null ? ' ($distro)' : '';
    return '$_osDisplayName$distroPart';
  }

  String get _osDisplayName {
    switch (os) {
      case 'macos':
        return 'macOS $osVersion';
      case 'windows':
        return 'Windows $osVersion';
      case 'linux':
        return osVersion;
      default:
        return '$os $osVersion';
    }
  }

  /// Returns a short label like "macOS (arm64)" or "Windows (x86_64)"
  String get shortLabel => '$os ($architecture)';

  @override
  String toString() => 'PlatformInfo(os: $os, arch: $architecture, '
      'version: $osVersion, distro: $distro)';
}
