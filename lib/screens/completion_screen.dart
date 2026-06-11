import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/install_provider.dart';
import '../providers/config_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/glass_container.dart';

/// Final screen shown after the installation wizard is complete.
class CompletionScreen extends StatelessWidget {
  const CompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final install = context.watch<InstallProvider>();
    final config = context.watch<ConfigProvider>();
    final isSuccess = install.progress.isComplete && config.isWritten;
    final hasError = install.progress.isFailed || config.writeError != null;

    return Scaffold(
      body: Column(
        children: [
          const CustomTitleBar(),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status icon
                    if (isSuccess)
                      _StatusIcon(
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                      ).animate().scale(
                            begin: const Offset(0.5, 0.5),
                            duration: 600.ms,
                            curve: Curves.elasticOut,
                          ),
                    if (hasError)
                      _StatusIcon(
                        icon: Icons.error_rounded,
                        color: AppColors.error,
                      ),

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      isSuccess ? '安装完成！' : '安装遇到问题',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ).animate().fadeIn(duration: 400.ms),

                    const SizedBox(height: 12),

                    Text(
                      isSuccess
                          ? 'Claude Code 已成功安装并配置完毕'
                          : '请检查以下信息并重试',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),

                    const SizedBox(height: 32),

                    // Summary cards
                    GlassContainer(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SummaryRow(
                            icon: Icons.terminal,
                            label: '安装状态',
                            value: install.progress.isComplete ? '已安装' : '未完成',
                            color: install.progress.isComplete
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          if (install.progress.installedVersion != null) ...[
                            const SizedBox(height: 8),
                            _SummaryRow(
                              icon: Icons.info_outline,
                              label: '版本',
                              value: install.progress.installedVersion!,
                              color: AppColors.textSecondary,
                            ),
                          ],
                          const SizedBox(height: 12),
                          _SummaryRow(
                            icon: Icons.settings,
                            label: '配置',
                            value: config.isWritten ? '已写入' : '未完成',
                            color: config.isWritten
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                          if (config.writeError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              config.writeError!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Tips
                    if (isSuccess)
                      GlassContainer(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '下一步',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _tipItem('打开终端，输入 claude 启动 Claude Code'),
                            _tipItem('首次使用可能需要等待几秒加载'),
                            _tipItem('使用 claude --help 查看更多命令'),
                          ],
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Action buttons
                    if (hasError)
                      SizedBox(
                        width: 200,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('返回重试'),
                        ),
                      ),

                    if (isSuccess)
                      SizedBox(
                        width: 200,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            // Close the app
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          child: const Text('完成'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tipItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_forward_ios,
              size: 12, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StatusIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Icon(icon, color: color, size: 48),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
        ),
      ],
    );
  }
}
