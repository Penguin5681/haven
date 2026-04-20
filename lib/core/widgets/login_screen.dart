import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_colors.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onSuccess;
  final String role;

  const LoginScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onSuccess,
    required this.role,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      await AuthService.instance.login(_emailCtrl.text, _passwordCtrl.text, role: widget.role);
      if (mounted) {
        widget.onSuccess();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    if (_isGoogleLoading) return;

    setState(() => _isGoogleLoading = true);

    try {
      final account = await GoogleSignIn(scopes: const ['email']).signIn();
      if (account == null) return;

      await AuthService.instance.googleAuth(
        email: account.email,
        fullName: account.displayName?.trim().isNotEmpty == true
            ? account.displayName!.trim()
            : account.email.split('@').first,
        profilePhotoUrl: account.photoUrl,
        role: widget.role,
      );

      if (mounted) {
        widget.onSuccess();
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 48),
                Hero(
                  tag: 'auth_icon',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.lock_outline, size: 40, color: widget.accentColor),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined, color: widget.accentColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: widget.accentColor, width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                      return 'Invalid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline, color: widget.accentColor),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: widget.accentColor,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: widget.accentColor, width: 2),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(foregroundColor: widget.accentColor),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Login',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5),
                        ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: const [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text('or'),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isGoogleLoading ? null : _continueWithGoogle,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: _isGoogleLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const FaIcon(FontAwesomeIcons.google, size: 16),
                  label: Text(
                    _isGoogleLoading ? 'Connecting...' : 'Continue with Google',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
