import 'package:flutter/material.dart';
import 'package:uniconnect_app/theme/app_theme.dart';
import 'package:uniconnect_app/screens/splash_screen.dart';

void main() {
  runApp(const UniConnectApp());
}

class UniConnectApp extends StatelessWidget {
  const UniConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniConnect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}