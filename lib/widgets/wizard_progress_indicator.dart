import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wizard_provider.dart';
import '../theme/app_theme.dart';

/// Horizontal step indicator showing 3 dots with labels and connecting lines.
class WizardProgressIndicator extends StatelessWidget {
  const WizardProgressIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<WizardProvider>();
    final currentIndex = wizard.currentStepIndex;

    const steps = ['系统检测', '安装', '配置'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connecting line
            final isCompleted = i ~/ 2 < currentIndex;
            return Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isCompleted
                      ? AppColors.primary
                      : AppColors.surfaceHover,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            );
          }

          final stepIndex = i ~/ 2;
          final isCompleted = stepIndex < currentIndex;
          final isActive = stepIndex == currentIndex;

          return _StepDot(
            label: steps[stepIndex],
            index: stepIndex + 1,
            isCompleted: isCompleted,
            isActive: isActive,
          );
        }),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final String label;
  final int index;
  final bool isCompleted;
  final bool isActive;

  const _StepDot({
    required this.label,
    required this.index,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dot / Circle
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted || isActive
                ? AppColors.primary
                : AppColors.surfaceHover,
            border: Border.all(
              color: isActive
                  ? AppColors.primaryLight
                  : (isCompleted ? AppColors.primary : Colors.transparent),
              width: isActive ? 2 : 0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 8,
                      spreadRadius: 0,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text(
                    '$index',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color:
                          isActive ? Colors.white : AppColors.textMuted,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        // Label
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            color: isActive || isCompleted
                ? AppColors.textPrimary
                : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
