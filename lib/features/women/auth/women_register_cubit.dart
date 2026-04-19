import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:bloc/bloc.dart';
import '../../../core/services/auth_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class WomenRegisterState {
  final int step;

  // Step 0 — Aadhaar
  final String? aadhaarImagePath;
  final String? aadhaarNumber;
  final bool isProcessing;

  // Step 1 — Personal Details
  final String? profilePhotoPath;
  final String name;
  final String email;
  final String phone;

  // Step 2 — Address
  final String address;
  final String pincode;
  final String state;
  final String district;

  // Step 3 — Security
  final String password;
  final String confirmPassword;

  // Submission Status
  final bool isSubmitting;
  final String? submissionError;
  final bool isSuccess;

  const WomenRegisterState({
    this.step = 0,
    this.aadhaarImagePath,
    this.aadhaarNumber,
    this.isProcessing = false,
    this.profilePhotoPath,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.pincode = '',
    this.state = '',
    this.district = '',
    this.password = '',
    this.confirmPassword = '',
    this.isSubmitting = false,
    this.submissionError,
    this.isSuccess = false,
  });

  WomenRegisterState copyWith({
    int? step,
    String? aadhaarImagePath,
    String? aadhaarNumber,
    bool? isProcessing,
    String? profilePhotoPath,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? pincode,
    String? state,
    String? district,
    String? password,
    String? confirmPassword,
    bool? isSubmitting,
    String? submissionError,
    bool? isSuccess,
  }) {
    return WomenRegisterState(
      step: step ?? this.step,
      aadhaarImagePath: aadhaarImagePath ?? this.aadhaarImagePath,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      isProcessing: isProcessing ?? this.isProcessing,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      pincode: pincode ?? this.pincode,
      state: state ?? this.state,
      district: district ?? this.district,
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

// ── Cubit ─────────────────────────────────────────────────────────────────────
class WomenRegisterCubit extends Cubit<WomenRegisterState> {
  WomenRegisterCubit() : super(const WomenRegisterState());

  void setProcessing(bool value) =>
      emit(state.copyWith(isProcessing: value));

  void setAadhaarScan({required String imagePath, String? number}) =>
      emit(state.copyWith(
        aadhaarImagePath: imagePath,
        aadhaarNumber: number,
        isProcessing: false,
      ));

  void clearAadhaar() => emit(state.copyWith(
        aadhaarImagePath: null,
        aadhaarNumber: null,
      ));

  void setProfilePhoto(String? path) =>
      emit(state.copyWith(profilePhotoPath: path));

  void goToStep(int step) => emit(state.copyWith(step: step));

  void updateForm({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? pincode,
    String? state,
    String? district,
    String? password,
    String? confirmPassword,
  }) =>
      emit(this.state.copyWith(
        name: name,
        email: email,
        phone: phone,
        address: address,
        pincode: pincode,
        state: state,
        district: district,
        password: password,
        confirmPassword: confirmPassword,
      ));

  Future<void> submitRegistration() async {
    if (state.aadhaarNumber == null || state.profilePhotoPath == null) {
      emit(state.copyWith(submissionError: 'Aadhaar or Profile Photo is missing.'));
      emit(state.copyWith(submissionError: ''));
      return;
    }

    emit(state.copyWith(isSubmitting: true, submissionError: ''));

    try {
      await AuthService.instance.signup(
        aadharNumber: state.aadhaarNumber!,
        fullName: state.name,
        email: state.email,
        phoneNumber: state.phone,
        profilePhoto: File(state.profilePhotoPath!),
        addressLine: state.address,
        pincode: state.pincode,
        state: state.state,
        district: state.district,
        password: state.password,
      );
      
      // Attempt auto-login to get the token
      try {
        await AuthService.instance.login(state.email, state.password, role: 'women');
      } catch (e) {
        debugPrint('Auto-login failed after signup: $e');
        // We still consider registration a success even if auto-login fails
      }

      emit(state.copyWith(isSubmitting: false, isSuccess: true));
    } catch (e, stackTrace) {
      debugPrint('Registration Error: $e');
      debugPrint('StackTrace: $stackTrace');
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      emit(state.copyWith(isSubmitting: false, submissionError: errorMessage));
      emit(state.copyWith(submissionError: ''));
    }
  }
}
