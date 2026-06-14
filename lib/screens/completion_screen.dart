import 'dart:io' show exit;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/install_provider.dart';
import '../providers/config_provider.dart';
import '../providers/wizard_provider.dart';
import '../services/install_service.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_button.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/glass_container.dart';
import 'wizard_pages/step_configure.dart';

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
                    if (hasError) ...[
                      SizedBox(
                        width: 200,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('返回重试'),
                        ),
                      ),
                    ],

                    if (isSuccess) ...[
                      // Open Claude Code button
                      SizedBox(
                        width: 280,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await launchClaudeInTerminal();
                            await Future.delayed(const Duration(milliseconds: 500));
                            exit(0);
                          },
                          icon: const Icon(Icons.terminal_rounded, size: 20),
                          label: const Text('打开 Claude Code 并退出',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Re-configure button
                      SizedBox(
                        width: 260,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DirectConfigureScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.settings, size: 16),
                          label: const Text('重新配置 API'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.glassBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),

                    ],
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

// ─── Direct Configure Screen (for re-config after installation) ──

class DirectConfigureScreen extends StatefulWidget {
  const DirectConfigureScreen({super.key});

  @override
  State<DirectConfigureScreen> createState() => _DirectConfigureScreenState();
}

class _DirectConfigureScreenState extends State<DirectConfigureScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final config = context.read<ConfigProvider>();
      final wizard = context.read<WizardProvider>();
      wizard.setClaudeAlreadyInstalled(true);
      wizard.goToStep(WizardStep.configure);
      config.loadExistingConfig();
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();

    return Scaffold(
      body: Column(
        children: [
          const CustomTitleBar(),
          Expanded(
            child: const StepConfigure(),
          ),
          // Bottom save bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.background.withValues(alpha: 0.9),
              border: Border(top: BorderSide(color: AppColors.glassBorder)),
            ),
            child: Row(
              children: [
                AnimatedButton(
                  label: '返回',
                  onPressed: () => Navigator.of(context).pop(),
                  isPrimary: false,
                  width: 100,
                ),
                const Spacer(),
                AnimatedButton(
                  label: '保存配置',
                  onPressed: config.profile.apiKey?.isNotEmpty == true
                      ? () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          await config.writeConfig();
                          if (!mounted) return;
                          messenger.showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  Icon(Icons.check_circle, color: AppColors.success, size: 18),
                                  SizedBox(width: 10),
                                  Text('配置保存成功',
                                      style: TextStyle(fontSize: 14, color: Colors.white)),
                                ],
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.surfaceCard,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                          await Future.delayed(const Duration(milliseconds: 600));
                          if (mounted) nav.pop();
                        }
                      : null,
                  width: 140,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
