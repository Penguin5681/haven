import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/auth_service.dart';

class WomenRegisterState {
  final String email;
  final String password;
  final String confirmPassword;
  final bool isSubmitting;
  final String? submissionError;
  final bool isSuccess;

  const WomenRegisterState({
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.isSubmitting = false,
    this.submissionError,
    this.isSuccess = false,
  });

  WomenRegisterState copyWith({
    String? email,
    String? password,
    String? confirmPassword,
    bool? isSubmitting,
    String? submissionError,
    bool? isSuccess,
  }) {
    return WomenRegisterState(
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: submissionError != null && submissionError.isEmpty
          ? null
          : submissionError ?? this.submissionError,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}

class WomenRegisterCubit extends Cubit<WomenRegisterState> {
  WomenRegisterCubit() : super(const WomenRegisterState());

  void updateForm({
    String? email,
    String? password,
    String? confirmPassword,
  }) {
    emit(state.copyWith(
      email: email,
      password: password,
      confirmPassword: confirmPassword,
    ));
  }

  Future<void> submitRegistration() async {
    emit(state.copyWith(isSubmitting: true, submissionError: '', isSuccess: false));

    try {
      await AuthService.instance.signup(
        email: state.email,
        password: state.password,
        role: 'women',
      );

      // Ensure token exists even when backend signup response doesn't include it.
      await AuthService.instance.login(state.email, state.password, role: 'women');

      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } catch (e) {
      debugPrint('Registration Error: $e');
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      emit(state.copyWith(isSubmitting: false, submissionError: errorMessage));
      emit(state.copyWith(submissionError: ''));
    }
  }
}
