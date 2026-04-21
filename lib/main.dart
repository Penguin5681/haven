import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/role_select/role_select_screen.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HavenApp());
}

class HavenApp extends StatelessWidget {
  const HavenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saphora',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      themeMode: ThemeMode.light,
      home: const SplashScreen(nextScreen: RoleSelectScreen()),
    );
  }
}
