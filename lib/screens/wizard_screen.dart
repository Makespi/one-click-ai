import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wizard_provider.dart';
import '../providers/prerequisite_provider.dart';
import '../providers/install_provider.dart';
import '../providers/config_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_button.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/wizard_progress_indicator.dart';
import 'wizard_pages/step_system_check.dart';
import 'wizard_pages/step_install_progress.dart';
import 'wizard_pages/step_configure.dart';
import 'completion_screen.dart';

class WizardScreen extends StatefulWidget {
  const WizardScreen({super.key});

  @override
  State<WizardScreen> createState() => _WizardScreenState();
}

class _WizardScreenState extends State<WizardScreen> {
  final _pageController = PageController();
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    // Load existing config in the background
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingConfig();
    });
  }

  void _loadExistingConfig() {
    final config = context.read<ConfigProvider>();
    final wizard = context.read<WizardProvider>();
    config.loadExistingConfig().then((_) {
      if (!mounted) return;
      if (config.isAlreadyConfigured) {
        wizard.setSkipConfigure(true);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  /// Handle auto-advance by animating the PageView.
  void _handleAutoAdvance(WizardProvider wizard) {
    if (!mounted) return;
    _goToPage(wizard.currentStepIndex);
  }

  /// Go to completion screen.
  void _goToCompletion() {
    if (!mounted) return;
    final config = context.read<ConfigProvider>();
    if (!config.isWritten) {
      config.writeConfig();
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CompletionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Set up auto-advance listener
    if (!_listening) {
      _listening = true;
      final wizard = context.read<WizardProvider>();
      wizard.addListener(() {
        if (!mounted) return;
        final w = context.read<WizardProvider>();

        // Auto-advance: when install completes, move to next step
        if (w.currentStep == WizardStep.install && w.autoAdvanceEnabled) {
          final install = context.read<InstallProvider>();
          if (install.progress.isComplete) {
            w.attemptAutoAdvance(
              conditionsMet: true,
              isLastStep: w.shouldSkipConfigure,
              onAdvance: () => _handleAutoAdvance(w),
              onComplete: _goToCompletion,
            );
          }
        }

        // Auto-advance: when config is already set, after install go straight
        if (w.currentStep == WizardStep.configure && w.shouldSkipConfigure) {
          w.nextStep();
          _goToCompletion();
        }
      });
    }

    return Scaffold(
      body: Column(
        children: [
          const CustomTitleBar(),
          const WizardProgressIndicator(),
          Expanded(
            child: Consumer<WizardProvider>(
              builder: (context, wizard, _) {
                return PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    StepSystemCheck(),
                    StepInstallProgress(),
                    StepConfigure(),
                  ],
                );
              },
            ),
          ),
          _BottomNavBar(
            onPageChange: _goToPage,
            onComplete: _goToCompletion,
          ),
        ],
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final void Function(int index) onPageChange;
  final VoidCallback onComplete;

  const _BottomNavBar({
    required this.onPageChange,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<WizardProvider>(
      builder: (context, wizard, _) {
        final isFirst = wizard.currentStepIndex == 0;
        final isLast = wizard.currentStepIndex == 2;
        final prereq = context.read<PrerequisiteProvider>();
        final install = context.read<InstallProvider>();
        final config = context.read<ConfigProvider>();

        // Determine if Next button should be enabled
        bool canProceed = false;
        String buttonLabel = '下一步';

        switch (wizard.currentStep) {
          case WizardStep.systemCheck:
            canProceed = prereq.allReady;
            buttonLabel = '开始安装';
            break;
          case WizardStep.install:
            canProceed = install.progress.isComplete;
            buttonLabel = wizard.shouldSkipConfigure ? '完成' : '继续配置';
            break;
          case WizardStep.configure:
            canProceed = config.isAlreadyConfigured ||
                config.profile.apiKey?.isNotEmpty == true;
            buttonLabel = '完成配置';
            break;
          case WizardStep.complete:
            break;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.background.withValues(alpha: 0.9),
            border: Border(
              top: BorderSide(color: AppColors.glassBorder),
            ),
          ),
          child: Row(
            children: [
              if (!isFirst)
                AnimatedButton(
                  label: '上一步',
                  onPressed: () {
                    wizard.disableAutoAdvance();
                    wizard.previousStep();
                    onPageChange(wizard.currentStepIndex);
                  },
                  isPrimary: false,
                  width: 120,
                ),
              const Spacer(),
              if (wizard.shouldSkipConfigure && wizard.currentStep == WizardStep.install)
                // Show a note that config already exists
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle,
                          size: 14, color: AppColors.success),
                      const SizedBox(width: 6),
                      Text(
                        '已有配置，跳过设置',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              AnimatedButton(
                label: buttonLabel,
                onPressed: canProceed
                    ? () {
                        wizard.disableAutoAdvance();
                        if (isLast) {
                          onComplete();
                        } else {
                          wizard.nextStep();
                          onPageChange(wizard.currentStepIndex);
                        }
                      }
                    : null,
                width: 140,
              ),
            ],
          ),
        );
      },
    );
  }
}
