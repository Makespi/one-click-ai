import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

class CustomTitleBar extends StatefulWidget {
  const CustomTitleBar({super.key});

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.isMaximized().then((v) {
      if (mounted) setState(() => _isMaximized = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.background.withValues(alpha: 0.8),
        ),
        child: Row(
          children: [
            const SizedBox(width: 8),
            // App icon
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.accent],
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            // Title
            const Text(
              'One Click AI',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            // Window controls
            _WindowButton(
              icon: Icons.minimize_rounded,
              onTap: () => windowManager.minimize(),
            ),
            const SizedBox(width: 4),
            _WindowButton(
              icon: _isMaximized
                  ? Icons.filter_none_rounded
                  : Icons.crop_square_rounded,
              onTap: () {
                _isMaximized
                    ? windowManager.unmaximize()
                    : windowManager.maximize();
                setState(() => _isMaximized = !_isMaximized);
              },
            ),
            const SizedBox(width: 4),
            _WindowButton(
              icon: Icons.close_rounded,
              onTap: () => windowManager.close(),
              isClose: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;

  const _WindowButton({
    required this.icon,
    required this.onTap,
    this.isClose = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isClose ? Colors.transparent : Colors.transparent,
        ),
        child: Center(
          child: Icon(
            icon,
            size: 16,
            color: isClose
                ? AppColors.textSecondary
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
