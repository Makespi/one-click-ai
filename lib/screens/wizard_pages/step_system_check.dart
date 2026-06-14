import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../models/platform_info.dart';
import '../../models/prerequisite_result.dart';
import '../../providers/wizard_provider.dart';
import '../../providers/prerequisite_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

/// Wizard step 1: System check and prerequisite detection with auto-install.
class StepSystemCheck extends StatefulWidget {
  const StepSystemCheck({super.key});

  @override
  State<StepSystemCheck> createState() => _StepSystemCheckState();
}

class _StepSystemCheckState extends State<StepSystemCheck> {
  int _countdown = 0; // 0 = no countdown; >0 = counting down

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runChecks();
    });
  }

  void _runChecks() {
    final prereq = context.read<PrerequisiteProvider>();
    prereq.checkAll().then((_) {
      if (!mounted) return;
      final prereq = context.read<PrerequisiteProvider>();
      if (prereq.allReady) {
        // Everything already installed → jump to install step
        _autoAdvance();
      } else if (prereq.canAutoInstall) {
        // Missing deps + can auto-install → start countdown
        _startCountdown();
      }
      // else: can't auto-install → show manual instructions, user clicks button
    });
  }

  void _startCountdown() {
    setState(() => _countdown = 3);
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      if (_countdown <= 1) {
        setState(() => _countdown = 0);
        await _installAll();
        return false;
      }
      setState(() => _countdown--);
      return _countdown > 0;
    });
  }

  void _autoAdvance() {
    if (!mounted) return;
    final wizard = context.read<WizardProvider>();
    wizard.attemptAutoAdvance(conditionsMet: true);
  }

  Future<void> _autoInstall(String depName) async {
    final prereq = context.read<PrerequisiteProvider>();
    try {
      final success = await prereq.installDependency(depName);
      if (!mounted) return;
      if (success) {
        await prereq.recheckDependency(depName);
      }
    } catch (_) {}
    if (!mounted) return;
    final w = context.read<WizardProvider>();
    w.setCanProceed(prereq.allReady);
  }

  Future<void> _installAll() async {
    if (!mounted) return;
    final prereq = context.read<PrerequisiteProvider>();
    final missing = prereq.results
        .where((r) =>
            r.status == PrerequisiteStatus.missing ||
            r.status == PrerequisiteStatus.outdated)
        .where((r) => r.name != 'npm')
        .map((r) => r.name)
        .toList();

    for (final depName in missing) {
      if (!mounted) return;
      await _autoInstall(depName);
    }

    // After all installs, check and auto-advance
    if (!mounted) return;
    final p = context.read<PrerequisiteProvider>();
    if (p.allReady) {
      _autoAdvance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final platformInfo = context.watch<PlatformInfo>();
    final prereq = context.watch<PrerequisiteProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Your System
          Text('您的系统', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _osIcon(platformInfo.os),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(platformInfo.displayName,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('架构: ${platformInfo.architecture}',
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (platformInfo.hasPackageManager) ...[
                        const SizedBox(height: 4),
                        _pmBadge(platformInfo.packageManager!.displayName),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Section: Prerequisites
          Text('环境依赖检测',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // Prerequisite tiles with install buttons
          ...List.generate(prereq.results.length, (i) {
            final result = prereq.results[i];
            final installState = prereq.getInstallState(result.name);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PrerequisiteCard(
                result: result,
                index: i,
                installState: installState,
                canAutoInstall: false, // fully automatic, no manual buttons
                onInstall: () {},
                onRecheck: () {},
              ),
            );
          }),

          // Countdown / auto-install indicator
          if (!prereq.isChecking &&
              !prereq.allReady &&
              prereq.canAutoInstall &&
              !prereq.isAnyInstalling &&
              _countdown > 0) ...[
            const SizedBox(height: 8),
            Center(
              child: _CountdownBanner(countdown: _countdown),
            ).animate().fadeIn(duration: 300.ms),
          ],
          if (prereq.isAnyInstalling) ...[
            const SizedBox(height: 8),
            Center(
              child: _InstallingBanner(),
            ).animate().fadeIn(duration: 300.ms),
          ],
          // Manual install button only when can't auto-install
          if (!prereq.isChecking &&
              !prereq.allReady &&
              !prereq.canAutoInstall &&
              !prereq.isAnyInstalling) ...[
            const SizedBox(height: 4),
            Center(
              child: _CannotAutoInstallHint(),
            ).animate().fadeIn(duration: 300.ms),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _osIcon(String os) {
    IconData icon;
    Color color;
    switch (os) {
      case 'macos':
        icon = Icons.apple;
        color = Colors.white;
        break;
      case 'windows':
        icon = Icons.window;
        color = AppColors.info;
        break;
      case 'linux':
        icon = Icons.terminal;
        color = AppColors.warning;
        break;
      default:
        icon = Icons.computer;
        color = AppColors.textSecondary;
    }
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.15),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _pmBadge(String name) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: AppColors.success.withValues(alpha: 0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 12, color: AppColors.success),
          const SizedBox(width: 4),
          Text(name,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success)),
        ],
      ),
    );
  }
}

/// A prerequisite card that can expand to show install progress.
class _PrerequisiteCard extends StatelessWidget {
  final PrerequisiteResult result;
  final int index;
  final DepInstallState installState;
  final bool canAutoInstall;
  final VoidCallback onInstall;
  final VoidCallback onRecheck;

  const _PrerequisiteCard({
    required this.result,
    required this.index,
    required this.installState,
    required this.canAutoInstall,
    required this.onInstall,
    required this.onRecheck,
  });

  @override
  Widget build(BuildContext context) {
    final needsInstall =
        result.status == PrerequisiteStatus.missing ||
        result.status == PrerequisiteStatus.outdated;

    return Column(
      children: [
        GlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Main row
              Row(
                children: [
                  _statusIcon(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(result.name,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(result.statusMessage,
                            style: TextStyle(fontSize: 13, color: _statusColor)),
                      ],
                    ),
                  ),
                  if (result.version != null && result.isReady)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: AppColors.success.withValues(alpha: 0.15),
                      ),
                      child: Text('v${result.version}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success)),
                    ),
                  if (needsInstall && canAutoInstall) ...[
                    const SizedBox(width: 12),
                    _InstallButton(
                      isInstalling: installState.isInstalling,
                      onInstall: onInstall,
                    ),
                  ],
                  if (needsInstall && !canAutoInstall && installState.success == null) ...[
                    const SizedBox(width: 12),
                    // Show manual install hint for unsupported platforms
                    Icon(Icons.info_outline,
                        size: 20, color: AppColors.warning.withValues(alpha: 0.6)),
                  ],
                  if (installState.success == true && result.isReady)
                    const Icon(Icons.check_circle,
                        size: 20, color: AppColors.success),
                ],
              ),

              // Install output terminal
              if (installState.isInstalling || installState.success != null) ...[
                const SizedBox(height: 12),
                _TerminalOutput(
                  lines: installState.outputLines,
                  isCompleted: installState.success == true,
                  hasError: installState.success == false,
                  errorMessage: installState.error,
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate().fadeIn(
          duration: 300.ms,
          delay: (200 + index * 100).ms,
        );
  }

  Color get _statusColor {
    switch (result.status) {
      case PrerequisiteStatus.installed:
        return AppColors.success;
      case PrerequisiteStatus.outdated:
        return AppColors.warning;
      case PrerequisiteStatus.missing:
      case PrerequisiteStatus.error:
        return AppColors.error;
      case PrerequisiteStatus.checking:
        return AppColors.info;
      case PrerequisiteStatus.pending:
        return AppColors.textMuted;
    }
  }

  Widget _statusIcon() {
    switch (result.status) {
      case PrerequisiteStatus.installed:
        return _iconCircle(AppColors.success, Icons.check);
      case PrerequisiteStatus.outdated:
        return _iconCircle(AppColors.warning, Icons.warning_amber_rounded);
      case PrerequisiteStatus.missing:
      case PrerequisiteStatus.error:
        return _iconCircle(AppColors.error, Icons.close);
      case PrerequisiteStatus.checking:
        return SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
              strokeWidth: 2.5, color: AppColors.info),
        );
      case PrerequisiteStatus.pending:
        return _iconCircle(AppColors.textMuted, Icons.hourglass_empty);
    }
  }

  Widget _iconCircle(Color color, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

/// A small "auto install" button that becomes a spinner during install.
class _InstallButton extends StatelessWidget {
  final bool isInstalling;
  final VoidCallback onInstall;

  const _InstallButton({
    required this.isInstalling,
    required this.onInstall,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: isInstalling ? null : onInstall,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success.withValues(alpha: 0.15),
          foregroundColor: AppColors.success,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: isInstalling
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.success),
              )
            : const Text('自动安装'),
      ),
    );
  }
}

/// Terminal-like output panel showing real-time install logs.
class _TerminalOutput extends StatelessWidget {
  final List<String> lines;
  final bool isCompleted;
  final bool hasError;
  final String? errorMessage;

  const _TerminalOutput({
    required this.lines,
    this.isCompleted = false,
    this.hasError = false,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final displayLines = lines.isEmpty ? ['正在执行...'] : lines;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: AppColors.background,
        border: Border.all(
          color: isCompleted
              ? AppColors.success.withValues(alpha: 0.3)
              : hasError
                  ? AppColors.error.withValues(alpha: 0.3)
                  : AppColors.glassBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status bar
          Row(
            children: [
              Icon(
                isCompleted
                    ? Icons.check_circle
                    : hasError
                        ? Icons.error
                        : Icons.terminal,
                size: 14,
                color: isCompleted
                    ? AppColors.success
                    : hasError
                        ? AppColors.error
                        : AppColors.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                isCompleted
                    ? '安装完成'
                    : hasError
                        ? '安装失败'
                        : '安装中...',
                style: TextStyle(
                  fontSize: 11,
                  color: isCompleted
                      ? AppColors.success
                      : hasError
                          ? AppColors.error
                          : AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Output content
          SizedBox(
            height: 80,
            child: SingleChildScrollView(
              child: Text(
                displayLines.join('\n'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppColors.success,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (errorMessage != null && hasError) ...[
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 11, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }
}

/// Countdown banner shown before auto-install.
class _CountdownBanner extends StatelessWidget {
  final int countdown;

  const _CountdownBanner({required this.countdown});

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            height: 36,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    value: countdown / 3.0,
                    strokeWidth: 2.5,
                    backgroundColor: AppColors.surfaceHover,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
                Text(
                  '$countdown',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            '秒后自动安装缺失依赖...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner shown while auto-installing.
class _InstallingBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 14),
          Text(
            '正在自动安装缺失依赖，请稍候...',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hint when no package manager is available.
class _CannotAutoInstallHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline, size: 28, color: AppColors.warning),
          const SizedBox(height: 12),
          const Text(
            '未能检测到包管理器',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '请手动安装缺失的依赖后，点击"重新检测"。\n'
            'macOS 用户请安装 Homebrew: brew.sh',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              // recheck
              final prereq = context.read<PrerequisiteProvider>();
              prereq.checkAll();
            },
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('重新检测'),
          ),
        ],
      ),
    );
  }
}
