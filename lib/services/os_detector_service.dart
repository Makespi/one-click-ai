import 'dart:ffi';
import 'dart:io' show File, Platform, Process;

import '../models/platform_info.dart';

/// Service to detect the host OS, architecture, version, and package manager.
class OsDetectorService {
  OsDetectorService._();

  /// Detect and return comprehensive platform information.
  static PlatformInfo detect() {
    final os = _detectOs();
    final arch = _detectArchitecture();
    final homeDir = _detectHomeDir();

    return PlatformInfo(
      os: os,
      architecture: arch,
      osVersion: _detectOsVersion(os),
      distro: os == 'linux' ? _detectLinuxDistro() : null,
      homeDir: homeDir,
      packageManager: _detectPackageManager(os),
    );
  }

  /// Detect which package manager is available on the system.
  static PackageManager? _detectPackageManager(String os) {
    switch (os) {
      case 'macos':
        if (_commandExists('brew')) {
          return const PackageManager(
            id: 'brew',
            displayName: 'Homebrew',
            supportsUnattended: true,
          );
        }
        return null;
      case 'linux':
        // Try common package managers in priority order
        if (_commandExists('apt')) {
          return const PackageManager(
            id: 'apt',
            displayName: 'APT (apt)',
            supportsUnattended: true,
          );
        }
        if (_commandExists('dnf')) {
          return const PackageManager(
            id: 'dnf',
            displayName: 'DNF (dnf)',
            supportsUnattended: true,
          );
        }
        if (_commandExists('pacman')) {
          return const PackageManager(
            id: 'pacman',
            displayName: 'Pacman',
            supportsUnattended: true,
          );
        }
        return null;
      case 'windows':
        // Try winget first (built into Windows 11, available for 10)
        if (_commandExists('winget')) {
          return const PackageManager(
            id: 'winget',
            displayName: 'WinGet',
            supportsUnattended: true,
          );
        }
        // Fallback to Chocolatey
        if (_commandExists('choco')) {
          return const PackageManager(
            id: 'choco',
            displayName: 'Chocolatey',
            supportsUnattended: true,
          );
        }
        return null;
      default:
        return null;
    }
  }

  /// Check if a command exists on the system PATH.
  static bool _commandExists(String command) {
    try {
      if (Platform.isWindows) {
        // Try `where` first
        var result = Process.runSync('where', [command],
            runInShell: true);
        if (result.exitCode == 0 &&
            result.stdout.toString().trim().isNotEmpty) {
          return true;
        }
        // Fallback: try running `command --version` via cmd
        result = Process.runSync('cmd', ['/c', command, '--version'],
            runInShell: true);
        return result.exitCode == 0;
      }
      final result = Process.runSync('which', [command]);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static String _detectOs() {
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    return Platform.operatingSystem;
  }

  static String _detectArchitecture() {
    try {
      final abi = Abi.current();
      if (abi == Abi.macosX64 ||
          abi == Abi.linuxX64 ||
          abi == Abi.windowsX64) {
        return 'x86_64';
      }
      if (abi == Abi.macosArm64 || abi == Abi.linuxArm64) {
        return 'arm64';
      }
    } catch (_) {}
    return 'unknown';
  }

  static String _detectOsVersion(String os) {
    final ver = Platform.operatingSystemVersion;
    final major = ver.split('.').first;
    switch (os) {
      case 'macos':
        return _macOSVersionName(int.tryParse(major) ?? 14);
      case 'windows':
        return _windowsVersionName(int.tryParse(major) ?? 10);
      case 'linux':
        return 'Linux';
      default:
        return Platform.operatingSystemVersion;
    }
  }

  static String? _detectLinuxDistro() {
    try {
      final file = File('/etc/os-release');
      if (file.existsSync()) {
        final content = file.readAsStringSync();
        for (final line in content.split('\n')) {
          if (line.startsWith('PRETTY_NAME=')) {
            return line
                .substring('PRETTY_NAME='.length)
                .replaceAll('"', '')
                .trim();
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static String _detectHomeDir() {
    final env = Platform.environment;
    if (Platform.isWindows) {
      return env['USERPROFILE'] ?? env['HOMEDRIVE'] ?? r'C:\Users\Default';
    }
    return env['HOME'] ?? '/home';
  }

  static String _macOSVersionName(int major) {
    const names = {
      15: 'Sequoia',
      14: 'Sonoma',
      13: 'Ventura',
      12: 'Monterey',
      11: 'Big Sur',
      10: 'Catalina',
    };
    final name = names[major] ?? 'Unknown';
    return name;
  }

  static String _windowsVersionName(int major) {
    const names = {
      10: 'Windows 10/11',
      6: 'Windows 7/8',
    };
    return names[major] ?? 'Windows';
  }
}
