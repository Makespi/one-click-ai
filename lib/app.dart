import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';

class OneClickAiApp extends StatelessWidget {
  const OneClickAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One Click AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const WelcomeScreen(),
    );
  }
}
