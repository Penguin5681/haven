import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/aadhaar_ocr_service.dart';
import '../../../core/theme/app_colors.dart';
import 'women_register_cubit.dart';

class WomenRegisterScreen extends StatefulWidget {
  final VoidCallback? onSuccess;
  const WomenRegisterScreen({super.key, this.onSuccess});

  @override
  State<WomenRegisterScreen> createState() => _WomenRegisterScreenState();
}

class _WomenRegisterScreenState extends State<WomenRegisterScreen> {
  final _personalFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();
  final _securityFormKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  bool _controllersInitialised = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _initControllers(WomenRegisterState s) {
    if (_controllersInitialised) return;
    _nameCtrl = TextEditingController(text: s.name);
    _emailCtrl = TextEditingController(text: s.email);
    _phoneCtrl = TextEditingController(text: s.phone);
    _addressCtrl = TextEditingController(text: s.address);
    _pincodeCtrl = TextEditingController(text: s.pincode);
    _stateCtrl = TextEditingController(text: s.state);
    _districtCtrl = TextEditingController(text: s.district);
    _passwordCtrl = TextEditingController(text: s.password);
    _confirmPasswordCtrl = TextEditingController(text: s.confirmPassword);
    _controllersInitialised = true;
  }

  @override
  void dispose() {
    if (_controllersInitialised) {
      _nameCtrl.dispose();
      _emailCtrl.dispose();
      _phoneCtrl.dispose();
      _addressCtrl.dispose();
      _pincodeCtrl.dispose();
      _stateCtrl.dispose();
      _districtCtrl.dispose();
      _passwordCtrl.dispose();
      _confirmPasswordCtrl.dispose();
    }
    super.dispose();
  }

  // ── Aadhaar helpers ────────────────────────────────────────────────────────
  Future<void> _scanWithCamera(WomenRegisterCubit cubit) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission denied')));
      return;
    }
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No camera found')));
      return;
    }
    if (!mounted) return;
    final file = await Navigator.of(context).push<File>(
      MaterialPageRoute(
          builder: (_) => _CameraCapturePage(camera: cameras.first)),
    );
    if (file != null) await _processAadhaar(file, cubit);
  }

  Future<void> _pickFromGallery(WomenRegisterCubit cubit) async {
    final xFile =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xFile != null) await _processAadhaar(File(xFile.path), cubit);
  }

  Future<void> _processAadhaar(
      File file, WomenRegisterCubit cubit) async {
    cubit.setProcessing(true);
    cubit.setAadhaarScan(imagePath: file.path, number: null);

    final number =
        await AadhaarOcrService.instance.extractAadhaar(file);
    cubit.setAadhaarScan(imagePath: file.path, number: number);

    if (number == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not detect Aadhaar number. Try again.')));
    }
  }

  // ── Profile Photo Helper ───────────────────────────────────────────────────
  Future<void> _pickProfilePhoto(WomenRegisterCubit cubit) async {
    final xFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (xFile != null) {
      final file = File(xFile.path);
      final sizeInBytes = file.lengthSync();
      final sizeInMb = sizeInBytes / (1024 * 1024);
      if (sizeInMb > 7) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image is too large. Max allowed is 7MB.')),
        );
        return;
      }
      cubit.setProfilePhoto(file.path);
    }
  }

  // ── Form helpers ───────────────────────────────────────────────────────────
  void _saveFormToState(WomenRegisterCubit cubit) {
    cubit.updateForm(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      address: _addressCtrl.text,
      pincode: _pincodeCtrl.text,
      state: _stateCtrl.text,
      district: _districtCtrl.text,
      password: _passwordCtrl.text,
      confirmPassword: _confirmPasswordCtrl.text,
    );
  }

  void _submit(WomenRegisterCubit cubit) {
    if (!_securityFormKey.currentState!.validate()) return;
    _saveFormToState(cubit);
    cubit.submitRegistration();
  }

  Widget _buildStepContent(int step, WomenRegisterState state, WomenRegisterCubit cubit) {
    switch (step) {
      case 0:
        return _AadhaarStep(
          key: const ValueKey(0),
          state: state,
          cubit: cubit,
          onScanCamera: () => _scanWithCamera(cubit),
          onPickGallery: () => _pickFromGallery(cubit),
          onContinue: () {
            _saveFormToState(cubit);
            cubit.goToStep(1);
          },
        );
      case 1:
        return _PersonalDetailsStep(
          key: const ValueKey(1),
          formKey: _personalFormKey,
          state: state,
          nameCtrl: _nameCtrl,
          emailCtrl: _emailCtrl,
          phoneCtrl: _phoneCtrl,
          onPickPhoto: () => _pickProfilePhoto(cubit),
          onFieldChanged: () => _saveFormToState(cubit),
          onContinue: () {
            if (_personalFormKey.currentState!.validate()) {
              _saveFormToState(cubit);
              cubit.goToStep(2);
            }
          },
        );
      case 2:
        return _AddressStep(
          key: const ValueKey(2),
          formKey: _addressFormKey,
          addressCtrl: _addressCtrl,
          pincodeCtrl: _pincodeCtrl,
          stateCtrl: _stateCtrl,
          districtCtrl: _districtCtrl,
          onFieldChanged: () => _saveFormToState(cubit),
          onContinue: () {
            if (_addressFormKey.currentState!.validate()) {
              _saveFormToState(cubit);
              cubit.goToStep(3);
            }
          },
        );
      case 3:
        return _SecurityStep(
          key: const ValueKey(3),
          state: state,
          formKey: _securityFormKey,
          passwordCtrl: _passwordCtrl,
          confirmPasswordCtrl: _confirmPasswordCtrl,
          obscurePassword: _obscurePassword,
          obscureConfirmPassword: _obscureConfirmPassword,
          onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),
          onToggleConfirmPassword: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
          onFieldChanged: () => _saveFormToState(cubit),
          onSubmit: () => _submit(cubit),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  String _getStepTitle(int step) {
    switch (step) {
      case 0:
        return 'Step 1 of 4: Identity';
      case 1:
        return 'Step 2 of 4: Personal';
      case 2:
        return 'Step 3 of 4: Location';
      case 3:
        return 'Step 4 of 4: Security';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WomenRegisterCubit, WomenRegisterState>(
      listenWhen: (previous, current) {
        return previous.submissionError != current.submissionError ||
            previous.isSuccess != current.isSuccess;
      },
      listener: (context, state) {
        if (state.submissionError != null && state.submissionError!.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.submissionError!)));
        }
        if (state.isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Registration successful!')));
          if (widget.onSuccess != null) {
            widget.onSuccess!();
            Navigator.of(context).pop();
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      builder: (context, state) {
        final cubit = context.read<WomenRegisterCubit>();
        _initControllers(state);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(_getStepTitle(state.step)),
            backgroundColor: AppColors.surface,
            leading: state.step > 0
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _saveFormToState(cubit);
                      cubit.goToStep(state.step - 1);
                    },
                  )
                : null,
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _buildStepContent(state.step, state, cubit),
          ),
        );
      },
    );
  }
}

// ── Step 0: Aadhaar ───────────────────────────────────────────────────────────
class _AadhaarStep extends StatelessWidget {
  final WomenRegisterState state;
  final WomenRegisterCubit cubit;
  final VoidCallback onScanCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onContinue;

  const _AadhaarStep({
    super.key,
    required this.state,
    required this.cubit,
    required this.onScanCamera,
    required this.onPickGallery,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = state.aadhaarImagePath != null;
    final hasNumber = state.aadhaarNumber != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Scan your Aadhaar Card',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll automatically extract your Aadhaar number using OCR.",
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 32),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.roseTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: hasImage
                ? Image.file(File(state.aadhaarImagePath!), fit: BoxFit.cover)
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(FontAwesomeIcons.idCard,
                            size: 48, color: AppColors.rosePrimary),
                        SizedBox(height: 12),
                        Text('No image selected',
                            style: TextStyle(
                                fontSize: 14, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (hasNumber)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.greenLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.greenPrimary),
              ),
              child: Row(
                children: [
                  const FaIcon(FontAwesomeIcons.circleCheck,
                      color: AppColors.greenPrimary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Aadhaar: ${state.aadhaarNumber}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (state.isProcessing)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                  child: CircularProgressIndicator(
                      color: AppColors.rosePrimary)),
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: state.isProcessing ? null : onScanCamera,
            icon: const FaIcon(FontAwesomeIcons.camera, size: 18),
            label: const Text('Scan with Camera'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.isProcessing ? null : onPickGallery,
            icon: const FaIcon(FontAwesomeIcons.image, size: 18),
            label: const Text('Upload from Gallery'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: hasNumber ? onContinue : null,
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// ── Step 1: Personal Details ──────────────────────────────────────────────────
class _PersonalDetailsStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final WomenRegisterState state;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final VoidCallback onPickPhoto;
  final VoidCallback onFieldChanged;
  final VoidCallback onContinue;

  const _PersonalDetailsStep({
    super.key,
    required this.formKey,
    required this.state,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.onPickPhoto,
    required this.onFieldChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        onChanged: onFieldChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Personal Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.roseTint,
                    backgroundImage: state.profilePhotoPath != null
                        ? FileImage(File(state.profilePhotoPath!))
                        : null,
                    child: state.profilePhotoPath == null
                        ? const FaIcon(FontAwesomeIcons.user,
                            size: 40, color: AppColors.rosePrimary)
                        : null,
                  ),
                  InkWell(
                    onTap: onPickPhoto,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.rosePrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const FaIcon(FontAwesomeIcons.camera,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _field(nameCtrl, 'Full Name', Icons.person_outline,
                TextInputType.name),
            const SizedBox(height: 16),
            _field(emailCtrl, 'Email', Icons.email_outlined,
                TextInputType.emailAddress, validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                return 'Invalid email';
              }
              return null;
            }),
            const SizedBox(height: 16),
            _field(phoneCtrl, 'Phone Number', Icons.phone_outlined,
                TextInputType.phone, formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ], validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.length != 10) return 'Must be 10 digits';
              return null;
            }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 2: Address Details ───────────────────────────────────────────────────
class _AddressStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController addressCtrl;
  final TextEditingController pincodeCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController districtCtrl;
  final VoidCallback onFieldChanged;
  final VoidCallback onContinue;

  const _AddressStep({
    super.key,
    required this.formKey,
    required this.addressCtrl,
    required this.pincodeCtrl,
    required this.stateCtrl,
    required this.districtCtrl,
    required this.onFieldChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        onChanged: onFieldChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Location Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address Line',
                prefixIcon: Icon(Icons.home_outlined),
              ),
              maxLines: 2,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            _field(pincodeCtrl, 'Pincode', Icons.location_on_outlined,
                TextInputType.number, formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ], validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.length != 6) return 'Must be 6 digits';
              return null;
            }),
            const SizedBox(height: 16),
            _field(stateCtrl, 'State', Icons.map_outlined,
                TextInputType.text),
            const SizedBox(height: 16),
            _field(districtCtrl, 'District', Icons.location_city_outlined,
                TextInputType.text),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onContinue,
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 3: Security ──────────────────────────────────────────────────────────
class _SecurityStep extends StatelessWidget {
  final WomenRegisterState state;
  final GlobalKey<FormState> formKey;
  final TextEditingController passwordCtrl;
  final TextEditingController confirmPasswordCtrl;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmPassword;
  final VoidCallback onFieldChanged;
  final VoidCallback onSubmit;

  const _SecurityStep({
    super.key,
    required this.state,
    required this.formKey,
    required this.passwordCtrl,
    required this.confirmPasswordCtrl,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onTogglePassword,
    required this.onToggleConfirmPassword,
    required this.onFieldChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: formKey,
        onChanged: onFieldChanged,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Set Password',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: confirmPasswordCtrl,
              obscureText: obscureConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  icon: Icon(obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                  onPressed: onToggleConfirmPassword,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v != passwordCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: state.isSubmitting ? null : onSubmit,
              child: state.isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Submit Registration'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Field Widget ───────────────────────────────────────────────────────
Widget _field(
  TextEditingController ctrl,
  String label,
  IconData icon,
  TextInputType keyboard, {
  List<TextInputFormatter>? formatters,
  String? Function(String?)? validator,
}) {
  return TextFormField(
    controller: ctrl,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
    ),
    keyboardType: keyboard,
    inputFormatters: formatters,
    validator: validator ??
        (v) => v == null || v.trim().isEmpty ? 'Required' : null,
  );
}

// ── Camera capture page ───────────────────────────────────────────────────────
class _CameraCapturePage extends StatefulWidget {
  final CameraDescription camera;
  const _CameraCapturePage({required this.camera});

  @override
  State<_CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<_CameraCapturePage> {
  late CameraController _ctrl;
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _ctrl = CameraController(widget.camera, ResolutionPreset.high);
    _initFuture = _ctrl.initialize();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    try {
      final image = await _ctrl.takePicture();
      if (!mounted) return;
      Navigator.of(context).pop(File(image.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.white));
          }
          return Stack(
            children: [
              Positioned.fill(child: CameraPreview(_ctrl)),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 28),
                          ),
                          const Spacer(),
                          const Text('Scan Aadhaar Card',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const Spacer(),
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: GestureDetector(
                        onTap: _capture,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Container(
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
