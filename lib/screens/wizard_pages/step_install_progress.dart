import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/install_progress.dart';
import '../../providers/install_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_container.dart';

/// Wizard step 2: Installation progress with terminal output.
class StepInstallProgress extends StatefulWidget {
  const StepInstallProgress({super.key});

  @override
  State<StepInstallProgress> createState() => _StepInstallProgressState();
}

class _StepInstallProgressState extends State<StepInstallProgress> {
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
  Widget build(BuildContext context) {
    final install = context.watch<InstallProvider>();
    final progress = install.progress;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            progress.message,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Progress bar
          GlassContainer(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Animated progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress.percent),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
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
                // Percentage
                Text(
                  '${(progress.percent * 100).toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: progress.isFailed
                            ? AppColors.error
                            : progress.isComplete
                                ? AppColors.success
                                : AppColors.primary,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _stageLabel(progress),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Terminal output
          if (progress.outputLines.isNotEmpty)
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Text(
                        '终端输出',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppColors.background,
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        progress.outputLines.join('\n'),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: AppColors.success,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Error display
          if (progress.isFailed && progress.error != null) ...[
            const SizedBox(height: 24),
            GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      progress.error!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Success message
          if (progress.isComplete) ...[
            const SizedBox(height: 24),
            Text(
              progress.installedVersion != null
                  ? 'Claude Code ${progress.installedVersion} 已成功安装！'
                  : '安装完成！',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.success,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  String _stageLabel(dynamic progress) {
    switch (progress.stage) {
      case InstallStage.checkingRegistry:
        return '检查 npm 仓库...';
      case InstallStage.downloading:
        return '下载中...';
      case InstallStage.installing:
        return '安装中...';
      case InstallStage.verifying:
        return '验证安装...';
      case InstallStage.completed:
        return '安装完成';
      case InstallStage.failed:
        return '安装失败';
      default:
        return '准备中...';
    }
  }
}
