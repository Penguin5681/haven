import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const HavenApp());
}

class HavenApp extends StatelessWidget {
  const HavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Haven',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const _Placeholder(),
    );
  }
}

/// Temporary placeholder — replace with your router/home screen.
class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset(
          'assets/app_logo/purple_logo_no_bg.png',
          width: 120,
        ),
      ),
    );
  }
}
