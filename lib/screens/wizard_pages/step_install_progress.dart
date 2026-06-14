import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/install_progress.dart';
import '../../providers/install_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

/// Wizard step 2: Installation progress — left progress + right terminal.
class StepInstallProgress extends StatefulWidget {
  const StepInstallProgress({super.key});

  @override
  State<StepInstallProgress> createState() => _StepInstallProgressState();
}

class _StepInstallProgressState extends State<StepInstallProgress> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final installProvider = context.read<InstallProvider>();
      if (!installProvider.isInstalling && !installProvider.progress.isComplete) {
        installProvider.startInstall();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final install = context.watch<InstallProvider>();
    final progress = install.progress;

    // Auto-scroll terminal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 20, 36, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Left: Progress info ──────────────────────
          SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Large status icon
                _StatusIcon(progress: progress),
                const SizedBox(height: 16),

                // Progress bar
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: progress.percent),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) {
                            return LinearProgressIndicator(
                              value: value,
                              minHeight: 10,
                              backgroundColor: AppColors.surfaceHover,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                progress.isFailed
                                    ? AppColors.error
                                    : AppColors.primary,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${(progress.percent * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: progress.isFailed
                                  ? AppColors.error
                                  : progress.isComplete
                                      ? AppColors.success
                                      : AppColors.primary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        progress.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Step indicators
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _StepRow(
                        label: '验证 npm',
                        done: progress.percent > 0.10,
                        active: progress.stage == InstallStage.checkingRegistry,
                      ),
                      const SizedBox(height: 6),
                      _StepRow(
                        label: '下载安装',
                        done: progress.percent > 0.75,
                        active: progress.stage == InstallStage.installing,
                      ),
                      const SizedBox(height: 6),
                      _StepRow(
                        label: '验证完成',
                        done: progress.isComplete,
                        active: progress.stage == InstallStage.verifying,
                      ),
                    ],
                  ),
                ),

                // Error message
                if (progress.isFailed && progress.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    progress.error!,
                    style: const TextStyle(fontSize: 12, color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 20),

          // ── Right: Terminal output ────────────────────
          Expanded(
            child: GlassContainer(
              padding: const EdgeInsets.all(4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Terminal title bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF5F57),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFFBD2E),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF27CA40),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '终端输出',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    color: AppColors.glassBorder,
                  ),
                  // Terminal content
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: AppColors.background,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Text(
                          progress.outputLines.isNotEmpty
                              ? progress.outputLines.join('\n')
                              : '等待中...',
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
}

class _StatusIcon extends StatelessWidget {
  final InstallProgress progress;

  const _StatusIcon({required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, scale, _) {
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (progress.isFailed
                      ? AppColors.error
                      : progress.isComplete
                          ? AppColors.success
                          : AppColors.primary)
                  .withValues(alpha: 0.12),
            ),
            child: Icon(
              progress.isFailed
                  ? Icons.error_outline
                  : progress.isComplete
                      ? Icons.check_circle_rounded
                      : Icons.downloading_rounded,
              size: 40,
              color: progress.isFailed
                  ? AppColors.error
                  : progress.isComplete
                      ? AppColors.success
                      : AppColors.primary,
            ),
          ),
        );
      },
    );
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool active;

  const _StepRow({
    required this.label,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle : (active ? Icons.radio_button_checked : Icons.radio_button_unchecked),
          size: 14,
          color: done
              ? AppColors.success
              : active
                  ? AppColors.primary
                  : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: done
                ? AppColors.textPrimary
                : active
                    ? AppColors.textSecondary
                    : AppColors.textMuted,
          ),
        ),
        if (active) ...[
          const SizedBox(width: 6),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.primary,
            ),
          ),
        ],
      ],
    );
  }
}
