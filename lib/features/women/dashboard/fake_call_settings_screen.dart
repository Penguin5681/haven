import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/fake_call_service.dart';
import '../../../core/theme/app_colors.dart';

class FakeCallSettingsScreen extends StatefulWidget {
  const FakeCallSettingsScreen({super.key});

  @override
  State<FakeCallSettingsScreen> createState() => _FakeCallSettingsScreenState();
}

class _FakeCallSettingsScreenState extends State<FakeCallSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _normalDelayCtrl = TextEditingController();
  final _angryDelayCtrl = TextEditingController();
  final _angryRepeatCtrl = TextEditingController();
  final _callerNumberCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _normalDelayCtrl.dispose();
    _angryDelayCtrl.dispose();
    _angryRepeatCtrl.dispose();
    _callerNumberCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await FakeCallService.loadSettings();
    if (!mounted) return;

    _normalDelayCtrl.text = settings.normalDelaySeconds.toString();
    _angryDelayCtrl.text = settings.angryDelaySeconds.toString();
    _angryRepeatCtrl.text = settings.angryRepeatCount.toString();
    _callerNumberCtrl.text = settings.fakeCallerNumber;

    setState(() => _isLoading = false);
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final settings = FakeCallSettings(
        normalDelaySeconds: int.parse(_normalDelayCtrl.text.trim()),
        angryDelaySeconds: int.parse(_angryDelayCtrl.text.trim()),
        angryRepeatCount: int.parse(_angryRepeatCtrl.text.trim()),
        fakeCallerNumber: _callerNumberCtrl.text.trim(),
      );

      await FakeCallService.saveSettings(settings);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fake call settings saved.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save settings.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            children: [
              _SettingsSection(
                title: 'Normal Fake Call',
                subtitle: 'Number shown on the incoming fake call screen.',
                children: [
                  _settingsField(
                    controller: _normalDelayCtrl,
                    label: 'Delay before call (seconds)',
                    icon: Icons.timer_outlined,
                    maxLength: 3,
                    validator: (value) {
                      final n = int.tryParse(value?.trim() ?? '');
                      if (n == null || n < 1) return 'Enter at least 1 second';
                      if (n > 600) return 'Max 600 seconds';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'Angry Father Mode',
                subtitle: 'Repeated calls with configurable interval and count.',
                children: [
                  _settingsField(
                    controller: _angryDelayCtrl,
                    label: 'Delay between calls (seconds)',
                    icon: Icons.schedule_outlined,
                    maxLength: 3,
                    validator: (value) {
                      final n = int.tryParse(value?.trim() ?? '');
                      if (n == null || n < 1) return 'Enter at least 1 second';
                      if (n > 600) return 'Max 600 seconds';
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  _settingsField(
                    controller: _angryRepeatCtrl,
                    label: 'Number of calls',
                    icon: Icons.repeat_outlined,
                    maxLength: 2,
                    validator: (value) {
                      final n = int.tryParse(value?.trim() ?? '');
                      if (n == null || n < 1) return 'Enter at least 1';
                      if (n > 20) return 'Max 20 calls';
                      return null;
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _SettingsSection(
                title: 'Caller Identity',
                subtitle: 'Number displayed when the fake incoming call appears.',
                children: [
                  _settingsField(
                    controller: _callerNumberCtrl,
                    label: 'Caller number',
                    icon: Icons.phone_android_outlined,
                    maxLength: 15,
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return 'Caller number is required';
                      if (text.length < 7) return 'Number looks too short';
                      return null;
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingsField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required int maxLength,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: maxLength,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
      ],
      validator: validator,
      decoration: InputDecoration(
        counterText: '',
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
