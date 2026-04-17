import 'package:bloc/bloc.dart';

// ── State ─────────────────────────────────────────────────────────────────────
class WomenRegisterState {
  final int step;

  // Step 0 — Aadhaar
  final String? aadhaarImagePath;
  final String? aadhaarNumber;
  final bool isProcessing;

  // Step 1 — Form
  final String name;
  final String email;
  final String phone;
  final String address;
  final String pincode;
  final String state;
  final String district;

  const WomenRegisterState({
    this.step = 0,
    this.aadhaarImagePath,
    this.aadhaarNumber,
    this.isProcessing = false,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
    this.pincode = '',
    this.state = '',
    this.district = '',
  });

  WomenRegisterState copyWith({
    int? step,
    String? aadhaarImagePath,
    String? aadhaarNumber,
    bool? isProcessing,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? pincode,
    String? state,
    String? district,
  }) {
    return WomenRegisterState(
      step: step ?? this.step,
      aadhaarImagePath: aadhaarImagePath ?? this.aadhaarImagePath,
      aadhaarNumber: aadhaarNumber ?? this.aadhaarNumber,
      isProcessing: isProcessing ?? this.isProcessing,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      pincode: pincode ?? this.pincode,
      state: state ?? this.state,
      district: district ?? this.district,
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

  void goToStep(int step) => emit(state.copyWith(step: step));

  void updateForm({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? pincode,
    String? state,
    String? district,
  }) =>
      emit(this.state.copyWith(
        name: name,
        email: email,
        phone: phone,
        address: address,
        pincode: pincode,
        state: state,
        district: district,
      ));
}
