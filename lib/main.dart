import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'models/platform_info.dart';
import 'providers/wizard_provider.dart';
import 'providers/prerequisite_provider.dart';
import 'providers/install_provider.dart';
import 'providers/config_provider.dart';
import 'services/os_detector_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window manager for frameless custom title bar
  await _initWindow();

  // Detect the host platform
  final platformInfo = OsDetectorService.detect();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WizardProvider()),
        ChangeNotifierProvider(
          create: (_) => PrerequisiteProvider(platformInfo: platformInfo),
        ),
        ChangeNotifierProvider(create: (_) => InstallProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        Provider<PlatformInfo>.value(value: platformInfo),
      ],
      child: const OneClickAiApp(),
    ),
  );
}

Future<void> _initWindow() async {
  await windowManager.ensureInitialized();

  const options = WindowOptions(
    size: Size(900, 780),
    minimumSize: Size(800, 680),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
