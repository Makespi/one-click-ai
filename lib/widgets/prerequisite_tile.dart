import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/prerequisite_result.dart';
import '../theme/app_theme.dart';

/// A row widget displaying the result of a single prerequisite check.
class PrerequisiteTile extends StatelessWidget {
  final PrerequisiteResult result;
  final int index;

  const PrerequisiteTile({
    super.key,
    required this.result,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.surfaceCard.withValues(alpha: 0.6),
        border: Border.all(
          color: _borderColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Status icon
          _statusIcon(),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  result.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  result.statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ),
          // Version badge
          if (result.version != null && result.isReady)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.success.withValues(alpha: 0.15),
              ),
              child: Text(
                'v${result.version}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(
          duration: 300.ms,
          delay: (200 + index * 100).ms,
        );
  }

  Color get _borderColor {
    switch (result.status) {
      case PrerequisiteStatus.installed:
        return AppColors.success;
      case PrerequisiteStatus.outdated:
        return AppColors.warning;
      case PrerequisiteStatus.missing:
      case PrerequisiteStatus.error:
        return AppColors.error;
      case PrerequisiteStatus.checking:
        return AppColors.info;
      case PrerequisiteStatus.pending:
        return AppColors.glassBorder;
    }
  }

  Color get _textColor {
    switch (result.status) {
      case PrerequisiteStatus.installed:
        return AppColors.success;
      case PrerequisiteStatus.outdated:
        return AppColors.warning;
      case PrerequisiteStatus.missing:
      case PrerequisiteStatus.error:
        return AppColors.error;
      case PrerequisiteStatus.checking:
        return AppColors.info;
      case PrerequisiteStatus.pending:
        return AppColors.textMuted;
    }
  }

  Widget _statusIcon() {
    switch (result.status) {
      case PrerequisiteStatus.installed:
        return _iconCircle(AppColors.success, Icons.check);
      case PrerequisiteStatus.outdated:
        return _iconCircle(AppColors.warning, Icons.warning_amber_rounded);
      case PrerequisiteStatus.missing:
      case PrerequisiteStatus.error:
        return _iconCircle(AppColors.error, Icons.close);
      case PrerequisiteStatus.checking:
        return SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: AppColors.info,
          ),
        );
      case PrerequisiteStatus.pending:
        return _iconCircle(AppColors.textMuted, Icons.hourglass_empty);
    }
  }

  Widget _iconCircle(Color color, IconData icon) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
