import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/platform_info.dart';

class PlatformBadge extends StatelessWidget {
  final PlatformInfo platformInfo;

  const PlatformBadge({super.key, required this.platformInfo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.glassBorder),
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceCard.withValues(alpha: 0.8),
            AppColors.surfaceCard.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _osIcon(),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '检测到您的系统',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              Text(
                platformInfo.displayName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '架构: ${platformInfo.architecture}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _osIcon() {
    IconData icon;
    Color color;
    switch (platformInfo.os) {
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
}
