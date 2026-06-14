import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/platform_info.dart';
import '../../models/prerequisite_result.dart';
import '../../providers/wizard_provider.dart';
import '../../providers/prerequisite_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

/// Wizard step 1: System check — left status + right terminal.
class StepSystemCheck extends StatefulWidget {
  const StepSystemCheck({super.key});

  @override
  State<StepSystemCheck> createState() => _StepSystemCheckState();
}

class _StepSystemCheckState extends State<StepSystemCheck> {
  int _countdown = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runChecks());
  }

  void _runChecks() {
    final prereq = context.read<PrerequisiteProvider>();
    prereq.checkAll().then((_) {
      if (!mounted) return;
      final p = context.read<PrerequisiteProvider>();
      if (p.allReady) {
        _autoAdvance();
      } else if (p.canAutoInstall) {
        _startCountdown();
      }
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
    context.read<WizardProvider>().attemptAutoAdvance(conditionsMet: true);
  }

  Future<void> _autoInstall(String depName) async {
    final prereq = context.read<PrerequisiteProvider>();
    try {
      final success = await prereq.installDependency(depName);
      if (!mounted) return;
      if (success) await prereq.recheckDependency(depName);
    } catch (_) {}
    if (!mounted) return;
    context.read<WizardProvider>().setCanProceed(prereq.allReady);
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

    if (!mounted) return;
    final p = context.read<PrerequisiteProvider>();
    if (p.allReady) _autoAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final platformInfo = context.watch<PlatformInfo>();
    final prereq = context.watch<PrerequisiteProvider>();
    final anyInstalling = prereq.isAnyInstalling;

    // Collect all terminal output from all deps
    final allOutput = <String>[];
    for (final r in prereq.results) {
      final state = prereq.getInstallState(r.name);
      if (state.outputLines.isNotEmpty) {
        allOutput.add('[${r.name}]');
        allOutput.addAll(state.outputLines);
        allOutput.add('');
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 20, 36, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: System info + prerequisites ──────
          SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // System info card
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      _osIcon(platformInfo.os),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(platformInfo.displayName,
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text('架构: ${platformInfo.architecture} · ${platformInfo.packageManager?.displayName ?? "无包管理器"}',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Prerequisites list
                ...List.generate(prereq.results.length, (i) {
                  final result = prereq.results[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DepTile(result: result),
                  );
                }),

                const SizedBox(height: 8),

                // Countdown / status banner
                if (!prereq.isChecking && !prereq.allReady && prereq.canAutoInstall) ...[
                  if (_countdown > 0 && !anyInstalling)
                    GlassContainer(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 30, height: 30,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 30, height: 30,
                                  child: CircularProgressIndicator(
                                    value: _countdown / 3.0,
                                    strokeWidth: 2.5,
                                    backgroundColor: AppColors.surfaceHover,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text('$_countdown',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('秒后自动安装缺失依赖',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  if (anyInstalling)
                    GlassContainer(
                      padding: const EdgeInsets.all(14),
                      child: const Row(
                        children: [
                          SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                          SizedBox(width: 10),
                          Text('正在自动安装，请稍候...',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 20),

          // ── Right: Terminal output ─────────────────
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(4),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: const Row(
                      children: [
                        _TermDot(color: Color(0xFFFF5F57)),
                        SizedBox(width: 6),
                        _TermDot(color: Color(0xFFFFBD2E)),
                        SizedBox(width: 6),
                        _TermDot(color: Color(0xFF27CA40)),
                        SizedBox(width: 12),
                        Text('安装日志', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppColors.glassBorder),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: AppColors.background,
                      child: SingleChildScrollView(
                        child: Text(
                          allOutput.isNotEmpty ? allOutput.join('\n') : '等待依赖检测...',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.success,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _osIcon(String os) {
    final icon = os == 'macos' ? Icons.apple : os == 'windows' ? Icons.window_rounded : Icons.terminal_rounded;
    final color = os == 'macos' ? Colors.white : os == 'windows' ? AppColors.info : AppColors.warning;
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

class _DepTile extends StatelessWidget {
  final PrerequisiteResult result;

  const _DepTile({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.surfaceCard.withValues(alpha: 0.5),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: Row(
        children: [
          _statusIcon(),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(result.name, style: Theme.of(context).textTheme.titleMedium),
                Text(result.statusMessage, style: TextStyle(fontSize: 11, color: _color)),
              ],
            ),
          ),
          if (result.version != null && result.isReady)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: AppColors.success.withValues(alpha: 0.12),
              ),
              child: Text('v${result.version}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success)),
            ),
        ],
      ),
    );
  }

  Color get _color {
    switch (result.status) {
      case PrerequisiteStatus.installed: return AppColors.success;
      case PrerequisiteStatus.outdated: return AppColors.warning;
      case PrerequisiteStatus.missing:
      case PrerequisiteStatus.error: return AppColors.error;
      case PrerequisiteStatus.checking: return AppColors.info;
      case PrerequisiteStatus.pending: return AppColors.textMuted;
    }
  }

  Widget _statusIcon() {
    switch (result.status) {
      case PrerequisiteStatus.installed:
        return const Icon(Icons.check_circle, color: AppColors.success, size: 20);
      case PrerequisiteStatus.outdated:
        return const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20);
      case PrerequisiteStatus.missing:
      case PrerequisiteStatus.error:
        return const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20);
      case PrerequisiteStatus.checking:
        return const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.info));
      case PrerequisiteStatus.pending:
        return const Icon(Icons.radio_button_unchecked, color: AppColors.textMuted, size: 20);
    }
  }
}

class _TermDot extends StatelessWidget {
  final Color color;
  const _TermDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 10, height: 10,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color));
  }
}
