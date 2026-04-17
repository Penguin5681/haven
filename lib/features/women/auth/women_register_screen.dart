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
  const WomenRegisterScreen({super.key});

  @override
  State<WomenRegisterScreen> createState() => _WomenRegisterScreenState();
}

class _WomenRegisterScreenState extends State<WomenRegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers are seeded from cubit state on first build.
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _districtCtrl;

  bool _controllersInitialised = false;

  void _initControllers(WomenRegisterState s) {
    if (_controllersInitialised) return;
    _nameCtrl = TextEditingController(text: s.name);
    _emailCtrl = TextEditingController(text: s.email);
    _phoneCtrl = TextEditingController(text: s.phone);
    _addressCtrl = TextEditingController(text: s.address);
    _pincodeCtrl = TextEditingController(text: s.pincode);
    _stateCtrl = TextEditingController(text: s.state);
    _districtCtrl = TextEditingController(text: s.district);
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
    // Optimistically store the image path so it survives back-nav
    cubit.setAadhaarScan(imagePath: file.path, number: null);

    final number =
        await AadhaarOcrService.instance.extractAadhaar(file);
    cubit.setAadhaarScan(imagePath: file.path, number: number);

    if (number == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not detect Aadhaar number. Try again.')));
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
    );
  }

  void _submit(WomenRegisterCubit cubit) {
    if (!_formKey.currentState!.validate()) return;
    _saveFormToState(cubit);
    // TODO: hand off to backend
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration successful!')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WomenRegisterCubit, WomenRegisterState>(
      builder: (context, state) {
        final cubit = context.read<WomenRegisterCubit>();
        _initControllers(state);

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(state.step == 0
                ? 'Verify Aadhaar'
                : 'Complete Profile'),
            backgroundColor: AppColors.surface,
            // On step 1, back arrow saves form state first
            leading: state.step == 1
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      _saveFormToState(cubit);
                      cubit.goToStep(0);
                    },
                  )
                : null,
          ),
          body: state.step == 0
              ? _AadhaarStep(
                  state: state,
                  cubit: cubit,
                  onScanCamera: () => _scanWithCamera(cubit),
                  onPickGallery: () => _pickFromGallery(cubit),
                  onContinue: () => cubit.goToStep(1),
                )
              : _FormStep(
                  formKey: _formKey,
                  nameCtrl: _nameCtrl,
                  emailCtrl: _emailCtrl,
                  phoneCtrl: _phoneCtrl,
                  addressCtrl: _addressCtrl,
                  pincodeCtrl: _pincodeCtrl,
                  stateCtrl: _stateCtrl,
                  districtCtrl: _districtCtrl,
                  onSubmit: () => _submit(cubit),
                  onFieldChanged: () => _saveFormToState(cubit),
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

          // Image preview
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: AppColors.roseTint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 1.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: hasImage
                ? Image.file(File(state.aadhaarImagePath!),
                    fit: BoxFit.cover)
                : const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FaIcon(FontAwesomeIcons.idCard,
                            size: 48, color: AppColors.rosePrimary),
                        SizedBox(height: 12),
                        Text('No image selected',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
          ),

          const SizedBox(height: 16),

          // Detected number chip
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

// ── Step 1: Form ──────────────────────────────────────────────────────────────
class _FormStep extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController addressCtrl;
  final TextEditingController pincodeCtrl;
  final TextEditingController stateCtrl;
  final TextEditingController districtCtrl;
  final VoidCallback onSubmit;
  final VoidCallback onFieldChanged;

  const _FormStep({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.phoneCtrl,
    required this.addressCtrl,
    required this.pincodeCtrl,
    required this.stateCtrl,
    required this.districtCtrl,
    required this.onSubmit,
    required this.onFieldChanged,
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
              'Complete Your Profile',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            _field(nameCtrl, 'Full Name', Icons.person_outline,
                TextInputType.name),
            const SizedBox(height: 16),
            _field(emailCtrl, 'Email', Icons.email_outlined,
                TextInputType.emailAddress,
                validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                return 'Invalid email';
              }
              return null;
            }),
            const SizedBox(height: 16),
            _field(phoneCtrl, 'Phone Number', Icons.phone_outlined,
                TextInputType.phone,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (v.length != 10) return 'Must be 10 digits';
              return null;
            }),
            const SizedBox(height: 16),
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
                TextInputType.number,
                formatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                validator: (v) {
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
              onPressed: onSubmit,
              child: const Text('Submit Registration'),
            ),
          ],
        ),
      ),
    );
  }

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
