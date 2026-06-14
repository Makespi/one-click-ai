import 'dart:io' show HttpClient;
import 'dart:math' show pi, sin;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../models/platform_info.dart';
import '../services/activation_service.dart';
import '../services/install_service.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/liquid_background.dart';
import 'completion_screen.dart';
import 'wizard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  bool? _claudeInstalled;
  bool _showUninstall = false;
  bool _isUninstalling = false;
  final List<String> _uninstallOutput = [];
  bool? _networkOk;
  String _networkDetail = '检测中...';

  // Activation
  ActivationData? _activation;
  bool _activationChecked = false;
  final _codeController = TextEditingController();
  bool _activating = false;
  String? _activateError;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _checkActivation();
    _checkClaudeCode();
    _checkNetwork();
  }

  Future<void> _checkActivation() async {
    final data = await ActivationService.readActivation();
    if (mounted) {
      setState(() {
        _activation = data;
        _activationChecked = true;
      });
    }
  }

  Future<void> _doActivate() async {
    final code = _codeController.text.replaceAll('-', '').toUpperCase();
    if (code.length != 16) {
      setState(() => _activateError = '请输入完整的16位激活码');
      return;
    }
    // Format: BD72-12D8-A0C5-3A61
    final formatted = '${code.substring(0, 4)}-${code.substring(4, 8)}-${code.substring(8, 12)}-${code.substring(12, 16)}';

    setState(() {
      _activating = true;
      _activateError = null;
    });

    final result = await ActivationService.activate(formatted);
    if (mounted) {
      setState(() {
        _activating = false;
        if (result.success) {
          _activation = result.data;
          _activateError = null;
          _codeController.clear();
        } else {
          _activateError = result.message;
        }
      });
    }
  }

  Future<void> _checkNetwork() async {
    try {
      final stopwatch = Stopwatch()..start();
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final request = await client.getUrl(Uri.parse('https://registry.npmjs.org'));
      final response = await request.close();
      stopwatch.stop();
      client.close();
      if (mounted) {
        setState(() {
          _networkOk = response.statusCode < 500;
          _networkDetail = '延迟 ${stopwatch.elapsedMilliseconds}ms';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _networkOk = false;
          _networkDetail = '网络不可用';
        });
      }
    }
  }

  Future<void> _checkClaudeCode() async {
    final installed = await InstallService().isClaudeCodeInstalled();
    if (mounted) setState(() => _claudeInstalled = installed);
  }

  bool get _isActivated =>
      _activation != null && _activation!.isValid;

  Future<void> _doUninstall() async {
    setState(() {
      _showUninstall = true;
      _isUninstalling = true;
      _uninstallOutput.add('正在卸载...');
    });
    final result = await InstallService().uninstallClaudeCode(
      onOutput: (line) {
        if (mounted) setState(() => _uninstallOutput.add(line));
      },
    );
    if (mounted) {
      if (result.success) {
        setState(() {
          _isUninstalling = false;
          _uninstallOutput.add('');
          _uninstallOutput.add('✓ 卸载成功');
          // Re-check actual status
          _checkClaudeCode();
          // Auto-hide output panel after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _showUninstall = false;
                _uninstallOutput.clear();
              });
            }
          });
        });
      } else {
        setState(() {
          _isUninstalling = false;
          _uninstallOutput.add('');
          _uninstallOutput.add('✗ 卸载失败: ${result.error}');
        });
      }
    }
  }

  @override
  void dispose() {
    _glowController.dispose();
    _codeController.dispose();
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
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 520,
                        child: Text(
                          '一键安装 Claude Code，自动配置开发环境。跨平台支持，从零到可用只需一次点击。',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textMuted,
                            height: 1.6,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 450.ms),
                      const SizedBox(height: 22),
                      _FeatureRow()
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 550.ms),
                      const SizedBox(height: 16),
                      _SystemCard(platformInfo: platformInfo)
                          .animate()
                          .fadeIn(duration: 400.ms, delay: 700.ms),

                      // Network + Claude status row
                      if (_networkOk != null || _claudeInstalled == true) ...[
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_networkOk != null) ...[
                              Icon(
                                _networkOk == true
                                    ? Icons.wifi_rounded
                                    : Icons.wifi_off_rounded,
                                size: 13,
                                color: _networkOk == true
                                    ? AppColors.success.withValues(alpha: 0.7)
                                    : AppColors.error.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _networkOk == true
                                    ? '网络正常'
                                    : '网络异常',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: _networkOk == true
                                      ? AppColors.success.withValues(alpha: 0.7)
                                      : AppColors.error.withValues(alpha: 0.7),
                                ),
                              ),
                              if (_networkOk == true) ...[
                                const SizedBox(width: 4),
                                Text(
                                  _networkDetail,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                            if (_networkOk != null &&
                                _claudeInstalled == true) ...[
                              const SizedBox(width: 18),
                              Container(
                                width: 1,
                                height: 12,
                                color: AppColors.glassBorder,
                              ),
                              const SizedBox(width: 18),
                            ],
                            if (_claudeInstalled == true) ...[
                              const Icon(Icons.check_circle,
                                  size: 13, color: AppColors.success),
                              const SizedBox(width: 5),
                              Text(
                                'Claude Code 已安装',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.success.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ).animate().fadeIn(duration: 400.ms),
                      ],

                      // ── Activation section ──────────────────────
                      if (_activationChecked && !_isActivated) ...[
                        const SizedBox(height: 18),
                        _ActivationPanel(
                          controller: _codeController,
                          activating: _activating,
                          error: _activateError,
                          onActivate: _doActivate,
                        ),
                      ],
                      if (_isActivated) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.verified_user,
                                size: 14, color: AppColors.success),
                            const SizedBox(width: 6),
                            Text(
                              '已激活 · 有效期至 ${_activation!.expireText}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.success.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // ── Buttons + uninstall (only when activated) ──
                      if (_isActivated) ...[
                        const SizedBox(height: 20),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final startButtonHalf = 125.0;
                            final centerX = constraints.maxWidth / 2;
                            return SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: Stack(
                                children: [
                                  Center(
                                    child: _StartButton(
                                      label: _networkOk == false
                                          ? '网络异常'
                                          : _claudeInstalled == true
                                              ? '开始配置'
                                              : '开始安装',
                                      isLoading: _isUninstalling,
                                      onPressed: (_isUninstalling || _networkOk == false)
                                          ? null
                                          : () {
                                        final isInstalled = _claudeInstalled == true;
                                        if (isInstalled) {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => const DirectConfigureScreen(),
                                            ),
                                          );
                                        } else {
                                          Navigator.of(context).pushReplacement(
                                            MaterialPageRoute(
                                              builder: (_) => const WizardScreen(),
                                            ),
                                          );
                                        }
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
                                ),
                                if (_claudeInstalled == true)
                                  Positioned(
                                    left: centerX + startButtonHalf + 12,
                                    top: 0,
                                    child: _UninstallButton(onTap: () {
                                      if (_isUninstalling) return;
                                      if (_showUninstall) {
                                        setState(() {
                                          _showUninstall = false;
                                          _uninstallOutput.clear();
                                        });
                                        return;
                                      }
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          backgroundColor: AppColors.surfaceCard,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          title: const Text('确认卸载',
                                              style: TextStyle(color: AppColors.textPrimary)),
                                          content: const Text(
                                            '确定要卸载 Claude Code 吗？\n卸载后需要重新安装才能使用。',
                                            style: TextStyle(color: AppColors.textSecondary),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(ctx).pop(),
                                              child: const Text('取消',
                                                  style: TextStyle(color: AppColors.textMuted)),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.of(ctx).pop();
                                                _doUninstall();
                                              },
                                              child: const Text('确认卸载',
                                                  style: TextStyle(color: AppColors.error)),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Network error hint
                      if (_networkOk == false) ...[
                        const SizedBox(height: 8),
                        Text(
                          '⚠ 网络连接异常，请检查网络后重试',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.warning.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],

                      // Uninstall output panel
                      if (_showUninstall && _uninstallOutput.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: 440,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: AppColors.background,
                            border: Border.all(color: AppColors.glassBorder),
                          ),
                          constraints: const BoxConstraints(maxHeight: 100),
                          child: SingleChildScrollView(
                            child: Text(
                              _uninstallOutput.join('\n'),
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: AppColors.success,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                      ], // end if (_isActivated)

                      const SizedBox(height: 18),
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
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
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
          Expanded(
            child: Column(
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
                  '${platformInfo.displayName} · ${platformInfo.architecture}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (platformInfo.hasPackageManager)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: Text(
                platformInfo.packageManager!.displayName,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryLight,
                ),
              ),
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
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;

  const _StartButton({required this.onPressed, this.label = '开始安装', this.isLoading = false});

  @override
  State<_StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<_StartButton> {
  bool _hovered = false;

  bool get _disabled => widget.onPressed == null || widget.isLoading;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _disabled ? null : (_) => setState(() => _hovered = true),
      onExit: _disabled ? null : (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: _disabled ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 250,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _disabled ? AppColors.surfaceHover : null,
            gradient: _disabled
                ? null
                : LinearGradient(
                    colors: _hovered
                        ? [AppColors.primaryLight, AppColors.accentLight]
                        : [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            boxShadow: _disabled
                ? []
                : _hovered
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
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isLoading) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  widget.isLoading ? '卸载中...' : widget.label,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: _disabled ? AppColors.textMuted : Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Uninstall button — fades in smoothly when Claude Code is installed.
class _UninstallButton extends StatefulWidget {
  final VoidCallback onTap;

  const _UninstallButton({required this.onTap});

  @override
  State<_UninstallButton> createState() => _UninstallButtonState();
}

class _UninstallButtonState extends State<_UninstallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    // Delayed start for staggered entrance
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 56,
          width: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppColors.surfaceCard.withValues(alpha: 0.3),
            border: Border.all(color: AppColors.glassBorder.withValues(alpha: 0.5)),
          ),
          child: const Icon(
            Icons.delete_outline_rounded,
            size: 20,
            color: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Activation code input panel.
class _ActivationPanel extends StatefulWidget {
  final TextEditingController controller;
  final bool activating;
  final String? error;
  final VoidCallback onActivate;

  const _ActivationPanel({
    required this.controller,
    required this.activating,
    this.error,
    required this.onActivate,
  });

  @override
  State<_ActivationPanel> createState() => _ActivationPanelState();
}

class _ActivationPanelState extends State<_ActivationPanel> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.glassBorder),
        color: AppColors.surfaceCard.withValues(alpha: 0.3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.vpn_key_rounded, size: 16, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                '请输入激活码以继续使用',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 240,
                child: TextField(
                  controller: widget.controller,
                  enabled: !widget.activating,
                  textAlign: TextAlign.center,
                  maxLength: 19,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'BD72-12D8-A0C5-3A61',
                    hintStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                      color: AppColors.textMuted.withValues(alpha: 0.4),
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.glassBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                  onChanged: (v) => _formatCode(),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: widget.activating ? null : widget.onActivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: widget.activating
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('激活', style: TextStyle(fontSize: 14)),
                ),
              ),
            ],
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.error!,
              style: const TextStyle(fontSize: 12, color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  void _formatCode() {
    var text = widget.controller.text.replaceAll('-', '').toUpperCase();
    if (text.length > 16) text = text.substring(0, 16);
    final buf = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('-');
      buf.write(text[i]);
    }
    final formatted = buf.toString();
    if (formatted != widget.controller.text) {
      widget.controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }
}
