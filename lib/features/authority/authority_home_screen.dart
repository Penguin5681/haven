import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/auth_selection_screen.dart';
import '../../core/widgets/login_screen.dart';
import '../../core/services/auth_service.dart';
import 'auth/authority_register_screen.dart';
import 'dashboard/authority_dashboard_screen.dart';

class AuthorityHomeScreen extends StatefulWidget {
  const AuthorityHomeScreen({super.key});

  @override
  State<AuthorityHomeScreen> createState() => _AuthorityHomeScreenState();
}

class _AuthorityHomeScreenState extends State<AuthorityHomeScreen> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = await AuthService.instance.getToken();
    if (mounted) {
      setState(() {       
        _isLoggedIn = token != null;
        _isLoading = false;
      });
    }
  }

  void _onAuthSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  void _onLogout() async {
    await AuthService.instance.logout();
    if (mounted) {
      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isLoggedIn) {
      return AuthorityDashboardScreen(onLogout: _onLogout);
    }

    return AuthSelectionScreen(
      title: 'Responder Portal',
      subtitle: 'Monitor and respond to emergencies.\nPlease login or register.',
      accentColor: AppColors.bluePrimary,
      icon: Icons.security,
      loginScreen: LoginScreen(
        title: 'Authority Login',
        subtitle: 'Enter your credentials to access the portal.',
        accentColor: AppColors.bluePrimary,
        onSuccess: _onAuthSuccess,
        role: 'authority',
      ),
      registerScreen: AuthorityRegisterScreen(onSuccess: _onAuthSuccess),
    );
  }
}
