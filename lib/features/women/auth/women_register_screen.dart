import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';
import 'women_register_cubit.dart';

class WomenRegisterScreen extends StatefulWidget {
  final VoidCallback? onSuccess;

  const WomenRegisterScreen({super.key, this.onSuccess});

  @override
  State<WomenRegisterScreen> createState() => _WomenRegisterScreenState();
}

class _WomenRegisterScreenState extends State<WomenRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
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
        role: 'women',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed in with Google successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onSuccess?.call();
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red.shade800,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<WomenRegisterCubit>().updateForm(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
          confirmPassword: _confirmPasswordCtrl.text,
        );
    context.read<WomenRegisterCubit>().submitRegistration();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WomenRegisterCubit, WomenRegisterState>(
      listenWhen: (previous, current) =>
          previous.submissionError != current.submissionError ||
          previous.isSuccess != current.isSuccess,
      listener: (context, state) {
        if (state.submissionError != null && state.submissionError!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.submissionError!)),
          );
        }

        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created. Complete your profile from dashboard.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.onSuccess?.call();
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),
                    const Text(
                      'Create Your Account',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Just email and password for now. You can fill profile details later.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (email.isEmpty) return 'Email is required';
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                          return 'Invalid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Password is required';
                        if (value.length < 6) return 'Minimum 6 characters required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirmPasswordCtrl,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword,
                            );
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: state.isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.rosePrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(fontWeight: FontWeight.w700),
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
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _isGoogleLoading ? null : _continueWithGoogle,
                      icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const FaIcon(FontAwesomeIcons.google, size: 16),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: BorderSide(
                          color: AppColors.textSecondary.withAlpha(70),
                        ),
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      label: Text(
                        _isGoogleLoading
                            ? 'Connecting...'
                            : 'Continue with Google',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
