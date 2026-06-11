import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/config_provider.dart';
import '../providers/install_provider.dart';
import '../providers/wizard_provider.dart';
import '../services/install_service.dart';
import '../widgets/custom_title_bar.dart';
import '../widgets/wizard_progress_indicator.dart';
import 'completion_screen.dart';
import 'wizard_pages/step_configure.dart';
import 'wizard_pages/step_install_progress.dart';
import 'wizard_pages/step_system_check.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadExistingConfig();
    });
  }

  bool _preCheckDone = false;

  Future<void> _loadExistingConfig() async {
    if (_preCheckDone) return;
    _preCheckDone = true;

    final config = context.read<ConfigProvider>();
    final wizard = context.read<WizardProvider>();

    await config.loadExistingConfig();
    if (!mounted) return;

    final installService = InstallService();
    final claudeInstalled = await installService.isClaudeCodeInstalled();

    if (!mounted) return;

    if (claudeInstalled) {
      wizard.setClaudeAlreadyInstalled(true);
      wizard.goToStep(WizardStep.configure);
      if (config.isAlreadyConfigured) {
        wizard.setSkipConfigure(true);
      }
      _goToPage(wizard.currentStepIndex);
    } else if (config.isAlreadyConfigured) {
      wizard.setSkipConfigure(true);
    }
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

  void _handleAutoAdvance(WizardProvider wizard) {
    if (!mounted) return;
    _goToPage(wizard.currentStepIndex);
  }

  Future<void> _goToCompletion() async {
    if (!mounted) return;
    final config = context.read<ConfigProvider>();
    try {
      if (!config.isWritten) {
        await config.writeConfig();
      }
    } catch (_) {}
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const CompletionScreen()),
    );
  }

  void _onStateChanged() {
    if (!mounted) return;
    final w = context.read<WizardProvider>();
    final install = context.read<InstallProvider>();
    final config = context.read<ConfigProvider>();

    // Auto-advance: install completed
    if (w.currentStep == WizardStep.install &&
        w.autoAdvanceEnabled &&
        install.progress.isComplete) {
      w.attemptAutoAdvance(
        conditionsMet: true,
        isLastStep: w.shouldSkipConfigure,
        onAdvance: () => _handleAutoAdvance(w),
        onComplete: () => _goToCompletion(),
      );
    }

    // Auto-advance: configure step — skip if already set
    if (w.currentStep == WizardStep.configure && w.shouldSkipConfigure) {
      w.nextStep();
      _goToCompletion();
    }

    // Auto-advance: configure step — API key filled, go to completion
    if (w.currentStep == WizardStep.configure &&
        w.autoAdvanceEnabled &&
        config.profile.apiKey?.isNotEmpty == true) {
      w.attemptAutoAdvance(
        conditionsMet: true,
        isLastStep: true,
        onComplete: () => _goToCompletion(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_listening) {
      _listening = true;
      final wizard = context.read<WizardProvider>();
      final install = context.read<InstallProvider>();
      final config = context.read<ConfigProvider>();
      wizard.addListener(_onStateChanged);
      install.addListener(_onStateChanged);
      config.addListener(_onStateChanged);
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
        ],
      ),
    );
  }
}
