import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/auth_selection_screen.dart';
import '../../core/widgets/login_screen.dart';
import 'auth/women_register_cubit.dart';
import 'auth/women_register_screen.dart';
import '../../core/services/auth_service.dart';
import 'dashboard/women_dashboard_screen.dart';

class WomenHomeScreen extends StatefulWidget {
  const WomenHomeScreen({super.key});

  @override
  State<WomenHomeScreen> createState() => _WomenHomeScreenState();
}

class _WomenHomeScreenState extends State<WomenHomeScreen> {
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

  void _onRegistrationSuccess() {
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
      return WomenDashboardScreen(onLogout: _onLogout);
    }

    return AuthSelectionScreen(
      title: 'Welcome to Haven',
      subtitle: 'Your personal safety companion.\nPlease login or create an account.',
      accentColor: AppColors.rosePrimary,
      icon: Icons.shield,
      loginScreen: LoginScreen(
        title: 'Welcome Back',
        subtitle: 'Login to access your safe space.',
        accentColor: AppColors.rosePrimary,
        onSuccess: _onRegistrationSuccess,
        role: 'women',
      ),
      registerScreen: BlocProvider(
        create: (_) => WomenRegisterCubit(),
        child: WomenRegisterScreen(onSuccess: _onRegistrationSuccess),
      ),
    );
  }
}
