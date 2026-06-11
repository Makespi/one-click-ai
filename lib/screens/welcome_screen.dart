import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/platform_info.dart';
import '../services/install_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/liquid_background.dart';
import 'wizard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  bool? _claudeInstalled; // null = checking, true/false = result

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _checkClaudeCode();
  }

  Future<void> _checkClaudeCode() async {
    final installed = await InstallService().isClaudeCodeInstalled();
    if (mounted) setState(() => _claudeInstalled = installed);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final platformInfo = context.watch<PlatformInfo>();

    return Scaffold(
      body: LiquidBackground(
        child: Column(
          children: [
            const CustomTitleBar(),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 48,
                    right: 48,
                    top: 24,
                    bottom: 32,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroIcon(glowController: _glowController),
                      const SizedBox(height: 24),
                      Text(
                        'Claude Code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 5,
                          color: AppColors.textMuted,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 100.ms),
                      const SizedBox(height: 8),
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [AppColors.primaryLight, AppColors.accentLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(bounds),
                        child: const Text(
                          'One Click AI',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                            color: Colors.white,
                            height: 1.05,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms, delay: 200.ms)
                          .scale(
                            begin: const Offset(0.9, 0.9),
                            duration: 500.ms,
                            delay: 200.ms,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(height: 16),
                      Text(
                        '自动化安装工具',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                          letterSpacing: -0.3,
                          height: 1.3,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 350.ms),
                      const SizedBox(height: 12),
                      Text(
                        '一键安装 Claude Code，自动配置开发环境。\n跨平台支持，从零到可用只需一次点击。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 450.ms),
                      const SizedBox(height: 22),
                      _FeatureRow()
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 550.ms),
                      const SizedBox(height: 22),
                      _SystemCard(platformInfo: platformInfo)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 700.ms),
                      const SizedBox(height: 24),
                      _StartButton(
                        label: _claudeInstalled == true ? '去配置' : '开始安装',
                        onPressed: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const WizardScreen(),
                            ),
                          );
                        },
                      )
                          .animate()
                          .fadeIn(duration: 600.ms, delay: 1300.ms)
                          .scale(
                            begin: const Offset(0.95, 0.95),
                            duration: 600.ms,
                            delay: 1300.ms,
                            curve: Curves.easeOutBack,
                          ),
                      const SizedBox(height: 24),
                      Text(
                        'v1.0.0 · macOS · Windows · Linux',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textMuted.withValues(alpha: 0.6),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 1600.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub-widgets ───────────────────────────────────────────────────

class _HeroIcon extends StatelessWidget {
  final AnimationController glowController;

  const _HeroIcon({required this.glowController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glowController,
      builder: (context, child) {
        final glowOpacity = 0.25 + 0.15 * sin(glowController.value * 2 * pi);
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: glowOpacity),
                    AppColors.primary.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: glowOpacity * 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 24,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FeatureRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _FeatureChip(icon: Icons.download_done_rounded, label: '一键安装'),
        _FeatureChip(icon: Icons.settings_suggest_rounded, label: '自动配置'),
        _FeatureChip(icon: Icons.desktop_windows_rounded, label: '跨平台'),
      ],
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.glassBorder),
        color: AppColors.surfaceCard.withValues(alpha: 0.4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemCard extends StatelessWidget {
  final PlatformInfo platformInfo;

  const _SystemCard({required this.platformInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.surfaceCard.withValues(alpha: 0.3),
        border: Border.all(
          color: AppColors.glassBorder.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          _osIcon(platformInfo.os),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '已检测到您的系统',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textMuted,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                platformInfo.displayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
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
        icon = Icons.window_rounded;
        color = AppColors.info;
        break;
      case 'linux':
        icon = Icons.terminal_rounded;
        color = AppColors.warning;
        break;
      default:
        icon = Icons.computer_rounded;
        color = AppColors.textSecondary;
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _StartButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;

  const _StartButton({required this.onPressed, this.label = '开始安装'});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 250,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: _hovered
                  ? [AppColors.primaryLight, AppColors.accentLight]
                  : [AppColors.primary, AppColors.accent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
