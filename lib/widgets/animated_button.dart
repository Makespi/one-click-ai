import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A gradient button with hover/press animations.
class AnimatedButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final bool isPrimary;
  final bool isLoading;

  const AnimatedButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.height = 48,
    this.isPrimary = true,
    this.isLoading = false,
  });

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<AnimatedButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  Matrix4 _buildTransform() {
    final scale = _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0);
    return Matrix4.diagonal3Values(scale, scale, 1);
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height,
          transform: _buildTransform(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: widget.isPrimary
                ? LinearGradient(
                    colors: _isHovered
                        ? [AppColors.primaryLight, AppColors.accentLight]
                        : [AppColors.primary, AppColors.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isPrimary ? null : AppColors.surfaceCard,
            border: widget.isPrimary
                ? null
                : Border.all(color: AppColors.glassBorder),
            boxShadow: _isHovered && widget.isPrimary
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.isPrimary
                          ? Colors.white
                          : AppColors.primary,
                    ),
                  )
                : Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.isPrimary
                          ? Colors.white
                          : (_isHovered
                              ? AppColors.textPrimary
                              : AppColors.textSecondary),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
