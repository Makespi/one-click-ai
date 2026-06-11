import 'dart:async';
import 'package:flutter/material.dart';

/// Which step of the wizard is currently active.
enum WizardStep {
  systemCheck,
  install,
  configure,
  complete,
}

/// Orchestrates the wizard flow and global state.
///
/// Supports auto-advance: when the current step's conditions are met,
/// the wizard automatically moves to the next step after a short delay.
class WizardProvider extends ChangeNotifier {
  WizardStep _currentStep = WizardStep.systemCheck;
  bool _canProceed = false;
  bool _autoAdvanceEnabled = true;
  Timer? _autoAdvanceTimer;
  bool _shouldSkipConfigure = false;

  WizardStep get currentStep => _currentStep;
  bool get canProceed => _canProceed;
  bool get autoAdvanceEnabled => _autoAdvanceEnabled;
  bool get shouldSkipConfigure => _shouldSkipConfigure;

  int get currentStepIndex {
    switch (_currentStep) {
      case WizardStep.systemCheck:
        return 0;
      case WizardStep.install:
        return 1;
      case WizardStep.configure:
        return 2;
      case WizardStep.complete:
        return 3;
    }
  }

  void setCanProceed(bool value) {
    if (_canProceed != value) {
      _canProceed = value;
      notifyListeners();
    }
  }

  /// Call this from a wizard page to attempt auto-advance.
  /// If conditions are met and auto-advance is enabled, advances after a short delay.
  void attemptAutoAdvance({
    required bool conditionsMet,
    bool isLastStep = false,
    VoidCallback? onAdvance, // called when advancing (e.g. to animate PageView)
    VoidCallback? onComplete, // called when on the last step and conditions are met
  }) {
    _canProceed = conditionsMet;
    notifyListeners();

    if (!conditionsMet || !_autoAdvanceEnabled) return;

    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 800), () {
      if (isLastStep) {
        onComplete?.call();
      } else {
        nextStep();
        onAdvance?.call();
      }
    });
  }

  /// Disable auto-advance (e.g. when user manually navigates).
  void disableAutoAdvance() {
    _autoAdvanceEnabled = false;
    _autoAdvanceTimer?.cancel();
    notifyListeners();
  }

  /// Enable auto-advance again.
  void enableAutoAdvance() {
    _autoAdvanceEnabled = true;
  }

  /// Mark that the configure step should be skipped (already configured).
  void setSkipConfigure(bool value) {
    _shouldSkipConfigure = value;
    notifyListeners();
  }

  void goToStep(WizardStep step) {
    _currentStep = step;
    _canProceed = false;
    _autoAdvanceTimer?.cancel();
    notifyListeners();
  }

  void nextStep() {
    switch (_currentStep) {
      case WizardStep.systemCheck:
        _currentStep = WizardStep.install;
        break;
      case WizardStep.install:
        // Skip configure if already set up
        if (_shouldSkipConfigure) {
          _currentStep = WizardStep.complete;
        } else {
          _currentStep = WizardStep.configure;
        }
        break;
      case WizardStep.configure:
        _currentStep = WizardStep.complete;
        break;
      case WizardStep.complete:
        break;
    }
    _canProceed = false;
    notifyListeners();
  }

  void previousStep() {
    switch (_currentStep) {
      case WizardStep.systemCheck:
        break;
      case WizardStep.install:
        _currentStep = WizardStep.systemCheck;
        break;
      case WizardStep.configure:
        _currentStep = WizardStep.install;
        break;
      case WizardStep.complete:
        // If configure was skipped, go back to install
        if (_shouldSkipConfigure) {
          _currentStep = WizardStep.install;
        } else {
          _currentStep = WizardStep.configure;
        }
        break;
    }
    _canProceed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }
}
