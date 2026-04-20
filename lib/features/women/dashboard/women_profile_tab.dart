import 'dart:io';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/aadhaar_ocr_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

class WomenProfileTab extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>>? onProfileUpdated;

  const WomenProfileTab({super.key, this.onProfileUpdated});

  @override
  State<WomenProfileTab> createState() => _WomenProfileTabState();
}

class _WomenProfileTabState extends State<WomenProfileTab> {
  final _identityFormKey = GlobalKey<FormState>();
  final _contactFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _aadharCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSavingIdentity = false;
  bool _isSavingContact = false;
  bool _isSavingAddress = false;
  bool _isScanningAadhar = false;
  bool _isGoogleUser = false;
  String? _email;
  String? _networkPhotoUrl;
  File? _localPhoto;
  Map<String, dynamic> _initialProfile = const {};

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _aadharCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _stateCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);

    try {
      final profile = await AuthService.instance.getProfile();
      if (!mounted) return;

      final profileProvider = profile['auth_provider']?.toString().toLowerCase();
      final cachedProvider = (await AuthService.instance.getAuthProvider())?.toLowerCase();
      final provider = profileProvider ?? cachedProvider ?? '';

      _isGoogleUser = provider == 'google';
      _initialProfile = profile;
      _email = profile['email']?.toString();
      _networkPhotoUrl = profile['profile_photo_url']?.toString();

      _fullNameCtrl.text = profile['full_name']?.toString() ?? '';
      _phoneCtrl.text = profile['phone_number']?.toString() ?? '';
      _aadharCtrl.text = profile['aadhar_number']?.toString() ?? '';
      _addressCtrl.text = profile['address_line']?.toString() ?? '';
      _pincodeCtrl.text = profile['pincode']?.toString() ?? '';
      _stateCtrl.text = profile['state']?.toString() ?? '';
      _districtCtrl.text = profile['district']?.toString() ?? '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    if (_isGoogleUser) {
      _showGoogleLockedMessage('Profile photo');
      return;
    }

    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final imageBytes = await File(picked.path).readAsBytes();
    if (!mounted) return;
    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => _CircularCropPage(imageBytes: imageBytes),
      ),
    );

    if (croppedBytes == null) return;

    final file = await _writeTempJpeg(croppedBytes);

    final sizeInMb = file.lengthSync() / (1024 * 1024);
    if (sizeInMb > 7) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image is too large. Max allowed is 7MB.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _localPhoto = file);
  }

  Future<File> _writeTempJpeg(Uint8List bytes) async {
    final dir = Directory.systemTemp;
    final file = File(
      '${dir.path}/haven_profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _scanAadharWithOcr() async {
    if (_isScanningAadhar) return;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImageSourceSheet(),
    );

    if (source == null) return;

    setState(() => _isScanningAadhar = true);
    try {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 96);
      if (picked == null) return;

      final extracted = await AadhaarOcrService.instance.extractAadhaar(File(picked.path));
      if (!mounted) return;

      if (extracted == null || extracted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not detect Aadhaar number. Try a clearer image.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      _aadharCtrl.text = extracted;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Aadhaar detected: $extracted'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isScanningAadhar = false);
      }
    }
  }

  void _showGoogleLockedMessage(String fieldLabel) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$fieldLabel cannot be changed for Google accounts.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _isSavingAnySection =>
      _isSavingIdentity || _isSavingContact || _isSavingAddress;

  void _setSectionSaving(_ProfileSection section, bool value) {
    setState(() {
      switch (section) {
        case _ProfileSection.identity:
          _isSavingIdentity = value;
          break;
        case _ProfileSection.contact:
          _isSavingContact = value;
          break;
        case _ProfileSection.address:
          _isSavingAddress = value;
          break;
      }
    });
  }

  Future<void> _applySectionUpdate({
    required _ProfileSection section,
    String? fullName,
    String? phoneNumber,
    String? aadharNumber,
    String? addressLine,
    String? pincode,
    String? state,
    String? district,
    File? profilePhoto,
  }) async {
    if (_isSavingAnySection) return;

    _setSectionSaving(section, true);
    try {
      final response = await AuthService.instance.updateProfile(
        fullName: fullName,
        phoneNumber: phoneNumber,
        aadharNumber: aadharNumber,
        addressLine: addressLine,
        pincode: pincode,
        state: state,
        district: district,
        profilePhoto: profilePhoto,
      );

      final updatedProfile = (response['user'] is Map<String, dynamic>)
          ? response['user'] as Map<String, dynamic>
          : await AuthService.instance.getProfile();

      if (!mounted) return;

      _initialProfile = updatedProfile;
      _networkPhotoUrl = updatedProfile['profile_photo_url']?.toString();
      _localPhoto = null;
      widget.onProfileUpdated?.call(updatedProfile);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        _setSectionSaving(section, false);
      }
    }
  }

  Future<void> _saveIdentitySection() async {
    if (!(_identityFormKey.currentState?.validate() ?? false)) return;

    final fullName = _fullNameCtrl.text.trim();
    final aadhar = _aadharCtrl.text.trim();

    String? changedField(String key, String next) {
      final before = _initialProfile[key]?.toString().trim() ?? '';
      if (before == next) return null;
      return next;
    }

    final changedFullName = _isGoogleUser ? null : changedField('full_name', fullName);
    final changedAadhar = changedField('aadhar_number', aadhar);
    final changedPhoto = _isGoogleUser ? null : _localPhoto;

    if (changedFullName == null && changedAadhar == null && changedPhoto == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No identity changes to save.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _applySectionUpdate(
      section: _ProfileSection.identity,
      fullName: changedFullName,
      aadharNumber: changedAadhar,
      profilePhoto: changedPhoto,
    );
  }

  Future<void> _saveContactSection() async {
    if (!(_contactFormKey.currentState?.validate() ?? false)) return;

    final phone = _phoneCtrl.text.trim();
    final before = _initialProfile['phone_number']?.toString().trim() ?? '';
    final changedPhone = before == phone ? null : phone;

    if (changedPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No contact changes to save.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _applySectionUpdate(
      section: _ProfileSection.contact,
      phoneNumber: changedPhone,
    );
  }

  Future<void> _saveAddressSection() async {
    if (!(_addressFormKey.currentState?.validate() ?? false)) return;

    final address = _addressCtrl.text.trim();
    final pincode = _pincodeCtrl.text.trim();
    final stateName = _stateCtrl.text.trim();
    final district = _districtCtrl.text.trim();

    String? changedField(String key, String next) {
      final before = _initialProfile[key]?.toString().trim() ?? '';
      if (before == next) return null;
      return next;
    }

    final changedAddress = changedField('address_line', address);
    final changedPincode = changedField('pincode', pincode);
    final changedState = changedField('state', stateName);
    final changedDistrict = changedField('district', district);

    if (changedAddress == null &&
        changedPincode == null &&
        changedState == null &&
        changedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No address changes to save.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await _applySectionUpdate(
      section: _ProfileSection.address,
      addressLine: changedAddress,
      pincode: changedPincode,
      state: changedState,
      district: changedDistrict,
    );
  }

  Future<void> _openSettingsPlaceholder() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const _ProfileSettingsPlaceholderScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SafeArea(
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.6)),
      );
    }

    final profileComplete = AuthService.instance.isProfileComplete(_initialProfile);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadProfile,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'My Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _openSettingsPlaceholder,
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              profileComplete
                  ? 'Your profile is complete.'
                  : 'Complete your profile so emergency workflows can work better.',
              style: TextStyle(
                fontSize: 13,
                color: profileComplete ? AppColors.greenPrimary : AppColors.textSecondary,
              ),
            ),
            if (_isGoogleUser) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFD8CCFF)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 16, color: Color(0xFF6D28D9)),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Google account: Full name and profile photo are locked.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF5B21B6)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _ProfilePhotoCard(
              email: _email ?? '-',
              networkPhotoUrl: _networkPhotoUrl,
              localPhoto: _localPhoto,
              onPickPhoto: _pickProfilePhoto,
              disabled: _isGoogleUser,
            ),
            const SizedBox(height: 14),
              Form(
                key: _identityFormKey,
                child: _ProfileSectionCard(
                  title: 'Identity',
                  icon: Icons.badge_outlined,
                  action: _SectionSaveAction(
                    isSaving: _isSavingIdentity,
                    onPressed: _saveIdentitySection,
                  ),
                  children: [
                    _profileField(
                      controller: _fullNameCtrl,
                      label: 'Full Name',
                      icon: Icons.person_outline,
                      enabled: !_isGoogleUser,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Full name is required';
                        if (text.length < 2) return 'Name is too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _profileField(
                      controller: _aadharCtrl,
                      label: 'Aadhar Number',
                      icon: Icons.credit_card_rounded,
                      keyboardType: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(12),
                      ],
                      suffix: IconButton(
                        tooltip: 'Scan Aadhaar',
                        onPressed: _isScanningAadhar ? null : _scanAadharWithOcr,
                        icon: _isScanningAadhar
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.document_scanner_outlined),
                      ),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Aadhar number is required';
                        if (text.length != 12) return 'Must be 12 digits';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Form(
                key: _contactFormKey,
                child: _ProfileSectionCard(
                  title: 'Contact',
                  icon: Icons.call_outlined,
                  action: _SectionSaveAction(
                    isSaving: _isSavingContact,
                    onPressed: _saveContactSection,
                  ),
                  children: [
                    _profileField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Phone number is required';
                        if (text.length != 10) return 'Must be 10 digits';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Form(
                key: _addressFormKey,
                child: _ProfileSectionCard(
                  title: 'Address',
                  icon: Icons.home_outlined,
                  action: _SectionSaveAction(
                    isSaving: _isSavingAddress,
                    onPressed: _saveAddressSection,
                  ),
                  children: [
                    _profileField(
                      controller: _addressCtrl,
                      label: 'Address Line',
                      icon: Icons.pin_drop_outlined,
                      maxLines: 2,
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) {
                          return 'Address line is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _profileField(
                      controller: _pincodeCtrl,
                      label: 'Pincode',
                      icon: Icons.markunread_mailbox_outlined,
                      keyboardType: TextInputType.number,
                      formatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Pincode is required';
                        if (text.length != 6) return 'Must be 6 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _profileField(
                      controller: _stateCtrl,
                      label: 'State',
                      icon: Icons.map_outlined,
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) return 'State is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    _profileField(
                      controller: _districtCtrl,
                      label: 'District',
                      icon: Icons.location_city_outlined,
                      validator: (value) {
                        if ((value?.trim() ?? '').isEmpty) return 'District is required';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profileField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    Widget? suffix,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: formatters,
      validator: validator,
      maxLines: maxLines,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _ProfilePhotoCard extends StatelessWidget {
  final String email;
  final String? networkPhotoUrl;
  final File? localPhoto;
  final VoidCallback onPickPhoto;
  final bool disabled;

  const _ProfilePhotoCard({
    required this.email,
    required this.networkPhotoUrl,
    required this.localPhoto,
    required this.onPickPhoto,
    required this.disabled,
  });

  @override
  Widget build(BuildContext context) {
    final image = localPhoto != null
        ? FileImage(localPhoto!) as ImageProvider
        : ((networkPhotoUrl ?? '').trim().isNotEmpty
            ? NetworkImage(networkPhotoUrl!)
            : null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E0EA)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: AppColors.roseTint,
            backgroundImage: image,
            child: image == null
                ? const Icon(
                    Icons.person_rounded,
                    color: AppColors.rosePrimary,
                    size: 30,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Photo',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: disabled ? null : onPickPhoto,
            icon: Icon(disabled ? Icons.lock_outline : Icons.edit_rounded, size: 16),
            label: Text(disabled ? 'Locked' : 'Change'),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? action;

  const _ProfileSectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF0E0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.rosePrimary, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              action ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SectionSaveAction extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onPressed;

  const _SectionSaveAction({
    required this.isSaving,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSaving ? null : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 32),
        backgroundColor: AppColors.rosePrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: isSaving
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Text('Save', style: TextStyle(fontSize: 12)),
    );
  }
}

enum _ProfileSection { identity, contact, address }

class _ProfileSettingsPlaceholderScreen extends StatelessWidget {
  const _ProfileSettingsPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Center(
        child: Text(
          'Settings placeholder',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CircularCropPage extends StatefulWidget {
  final Uint8List imageBytes;

  const _CircularCropPage({required this.imageBytes});

  @override
  State<_CircularCropPage> createState() => _CircularCropPageState();
}

class _CircularCropPageState extends State<_CircularCropPage> {
  final CropController _controller = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Profile Photo'),
        actions: [
          TextButton(
            onPressed: _isCropping
                ? null
                : () {
                    setState(() => _isCropping = true);
                    _controller.cropCircle();
                  },
            child: _isCropping
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Done'),
          ),
        ],
      ),
      body: Crop(
        image: widget.imageBytes,
        controller: _controller,
        withCircleUi: true,
        onCropped: (result) {
          if (!mounted) return;

          switch (result) {
            case CropSuccess(:final croppedImage):
              Navigator.of(context).pop(croppedImage);
            case CropFailure():
              setState(() => _isCropping = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Unable to crop image. Please try again.'),
                ),
              );
          }
        },
      ),
    );
  }
}

class _ImageSourceSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Scan Aadhaar',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Use Camera'),
                onTap: () => Navigator.of(context).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(context).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
