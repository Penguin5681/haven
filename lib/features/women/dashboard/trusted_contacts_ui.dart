import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as device_contacts;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import 'trusted_contact.dart';

Future<TrustedContact?> showAddTrustedContactSheet(BuildContext context) {
  return showModalBottomSheet<TrustedContact>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddTrustedContactSheet(),
  );
}

String normalizePhoneNumber(String rawPhone) {
  return rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
}

class _DeviceContactOption {
  final String name;
  final String phoneNumber;

  const _DeviceContactOption({
    required this.name,
    required this.phoneNumber,
  });

  static _DeviceContactOption? fromContact(device_contacts.Contact contact) {
    String primaryPhone = '';
    for (final phone in contact.phones) {
      final number = phone.number.trim();
      if (number.isNotEmpty) {
        primaryPhone = number;
        break;
      }
    }

    if (primaryPhone.isEmpty) return null;

    final displayName = contact.displayName.trim();
    final fallbackName = primaryPhone;
    return _DeviceContactOption(
      name: displayName.isEmpty ? fallbackName : displayName,
      phoneNumber: primaryPhone,
    );
  }
}

Future<void> launchCallForContact({
  required BuildContext context,
  required TrustedContact contact,
}) async {
  final uri = Uri(scheme: 'tel', path: normalizePhoneNumber(contact.phoneNumber));
  await _launchContactUri(
    context: context,
    uri: uri,
    errorMessage: 'Unable to open the dialer right now.',
  );
}

Future<void> launchSmsForContact({
  required BuildContext context,
  required TrustedContact contact,
}) async {
  final uri = Uri(scheme: 'sms', path: normalizePhoneNumber(contact.phoneNumber));
  await _launchContactUri(
    context: context,
    uri: uri,
    errorMessage: 'Unable to open SMS right now.',
  );
}

Future<void> _launchContactUri({
  required BuildContext context,
  required Uri uri,
  required String errorMessage,
}) async {
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(errorMessage),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class TrustedContactsPreview extends StatelessWidget {
  final List<TrustedContact> contacts;
  final bool isLoading;
  final VoidCallback onAddContact;
  final VoidCallback onOpenContacts;

  const TrustedContactsPreview({
    super.key,
    required this.contacts,
    required this.isLoading,
    required this.onAddContact,
    required this.onOpenContacts,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 112,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
      );
    }

    if (contacts.isEmpty) {
      return TrustedContactsEmptyPrompt(
        onAddContact: onAddContact,
        onOpenContacts: onOpenContacts,
      );
    }

    final previewContacts = contacts.take(4).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: previewContacts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (i == previewContacts.length) {
                return _AddContactPreviewCard(onTap: onAddContact);
              }

              return _PreviewContactCard(contact: previewContacts[i]);
            },
          ),
        ),
        if (contacts.length > previewContacts.length) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onOpenContacts,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.rosePrimary,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            icon: const Icon(Icons.groups_rounded, size: 18),
            label: Text('View all ${contacts.length} trusted contacts'),
          ),
        ],
      ],
    );
  }
}

class TrustedContactsEmptyPrompt extends StatelessWidget {
  final VoidCallback onAddContact;
  final VoidCallback onOpenContacts;

  const TrustedContactsEmptyPrompt({
    super.key,
    required this.onAddContact,
    required this.onOpenContacts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF7FB), Color(0xFFFDF2F8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.rosePrimary.withAlpha(55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.group_add_rounded, color: AppColors.rosePrimary, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No trusted contacts yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Add people you trust so you can call or text them instantly during emergencies.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onAddContact,
                  icon: const Icon(Icons.add_rounded),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosePrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(42),
                  ),
                  label: const Text('Add Contact'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: onOpenContacts,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.rosePrimary,
                  side: BorderSide(color: AppColors.rosePrimary.withAlpha(130)),
                  minimumSize: const Size(84, 42),
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewContactCard extends StatelessWidget {
  final TrustedContact contact;

  const _PreviewContactCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0E0EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: AppColors.rosePrimary.withAlpha(30),
                child: Text(
                  contact.initials,
                  style: const TextStyle(
                    color: AppColors.rosePrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      contact.relationship,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _QuickContactAction(
                  icon: Icons.call_rounded,
                  text: 'Call',
                  color: AppColors.greenPrimary,
                  onTap: () => launchCallForContact(context: context, contact: contact),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickContactAction(
                  icon: Icons.sms_rounded,
                  text: 'SMS',
                  color: AppColors.bluePrimary,
                  onTap: () => launchSmsForContact(context: context, contact: contact),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickContactAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _QuickContactAction({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(55)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddContactPreviewCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AddContactPreviewCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 86,
          decoration: BoxDecoration(
            color: AppColors.roseTint,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.rosePrimary.withAlpha(70)),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline_rounded,
                  color: AppColors.rosePrimary, size: 26),
              SizedBox(height: 6),
              Text(
                'Add',
                style: TextStyle(
                  color: AppColors.rosePrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrustedContactsTab extends StatelessWidget {
  final List<TrustedContact> contacts;
  final bool isLoading;
  final VoidCallback onAddContact;
  final ValueChanged<TrustedContact> onDeleteContact;

  const TrustedContactsTab({
    super.key,
    required this.contacts,
    required this.isLoading,
    required this.onAddContact,
    required this.onDeleteContact,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Trusted Contacts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: onAddContact,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rosePrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  label: const Text('Add'),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2.4))
                : contacts.isEmpty
                    ? _ContactsTabEmptyState(onAddContact: onAddContact)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
                        itemCount: contacts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final contact = contacts[index];
                          return _TrustedContactTile(
                            contact: contact,
                            onDelete: () => onDeleteContact(contact),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _ContactsTabEmptyState extends StatelessWidget {
  final VoidCallback onAddContact;

  const _ContactsTabEmptyState({required this.onAddContact});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0E0EA)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.roseTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.groups_rounded,
                color: AppColors.rosePrimary,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Build your trusted circle',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Add family or friends who can quickly help when you need support.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddContact,
              icon: const Icon(Icons.add_rounded),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.rosePrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(44),
              ),
              label: const Text('Add First Trusted Contact'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustedContactTile extends StatelessWidget {
  final TrustedContact contact;
  final VoidCallback onDelete;

  const _TrustedContactTile({
    required this.contact,
    required this.onDelete,
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.rosePrimary.withAlpha(26),
            child: Text(
              contact.initials,
              style: const TextStyle(
                color: AppColors.rosePrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${contact.relationship} • ${contact.phoneNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _CircleIconButton(
            icon: Icons.call_rounded,
            color: AppColors.greenPrimary,
            onTap: () => launchCallForContact(context: context, contact: contact),
            tooltip: 'Call',
          ),
          const SizedBox(width: 6),
          _CircleIconButton(
            icon: Icons.sms_rounded,
            color: AppColors.bluePrimary,
            onTap: () => launchSmsForContact(context: context, contact: contact),
            tooltip: 'Send SMS',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            onSelected: (value) {
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('Remove contact'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String tooltip;

  const _CircleIconButton({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(20),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(70)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

class _AddTrustedContactSheet extends StatefulWidget {
  const _AddTrustedContactSheet();

  @override
  State<_AddTrustedContactSheet> createState() => _AddTrustedContactSheetState();
}

class _AddTrustedContactSheetState extends State<_AddTrustedContactSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _relationshipController = TextEditingController();
  bool _isPickingDeviceContacts = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final contact = TrustedContact(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      relationship: _relationshipController.text.trim().isEmpty
          ? 'Trusted contact'
          : _relationshipController.text.trim(),
      createdAt: DateTime.now(),
    );

    HapticFeedback.lightImpact();
    Navigator.of(context).pop(contact);
  }

  Future<void> _pickFromDeviceContacts() async {
    setState(() => _isPickingDeviceContacts = true);

    try {
      final permissionGranted = await device_contacts.FlutterContacts
          .requestPermission(readonly: true);
      if (!permissionGranted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Contacts permission denied. You can still add contact details manually.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final contacts = await device_contacts.FlutterContacts.getContacts(
        withProperties: true,
      );

      final options = <_DeviceContactOption>[];
      final seenNumbers = <String>{};
      for (final contact in contacts) {
        final option = _DeviceContactOption.fromContact(contact);
        if (option == null) continue;

        final normalized = normalizePhoneNumber(option.phoneNumber);
        if (normalized.isEmpty || seenNumbers.contains(normalized)) {
          continue;
        }

        seenNumbers.add(normalized);
        options.add(option);
      }

      options.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (options.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No phone contacts found on this device. Add one manually below.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (!mounted) return;
      final selected = await showModalBottomSheet<_DeviceContactOption>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _DeviceContactPickerSheet(contacts: options),
      );

      if (!mounted || selected == null) return;

      setState(() {
        _nameController.text = selected.name;
        _phoneController.text = selected.phoneNumber;
        if (_relationshipController.text.trim().isEmpty) {
          _relationshipController.text = 'Phone contact';
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to access contacts right now. Add contact manually instead.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPickingDeviceContacts = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottomInset + 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE7D3DE),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Add Trusted Contact',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'This person will be one-tap away for calls and emergency SMS.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed:
                          _isPickingDeviceContacts ? null : _pickFromDeviceContacts,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                        side: BorderSide(
                          color: AppColors.rosePrimary.withAlpha(90),
                        ),
                        foregroundColor: AppColors.rosePrimary,
                      ),
                      icon: _isPickingDeviceContacts
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.contacts_rounded),
                      label: Text(
                        _isPickingDeviceContacts
                            ? 'Loading contacts...'
                            : 'Pick from device contacts',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Or enter contact details manually below',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InputLabel(text: 'Name'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration('e.g. Priya Sharma'),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return 'Name is required';
                        if (text.length < 2) return 'Name is too short';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _InputLabel(text: 'Phone Number'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      decoration: _fieldDecoration('e.g. +91 98765 43210'),
                      validator: (value) {
                        final cleaned = normalizePhoneNumber(value ?? '');
                        if (cleaned.isEmpty) return 'Phone number is required';
                        if (cleaned.length < 8) return 'Phone number looks invalid';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    _InputLabel(text: 'Relationship (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _relationshipController,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: _fieldDecoration('e.g. Sister, Friend, Colleague'),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              minimumSize: const Size.fromHeight(46),
                              side: const BorderSide(color: Color(0xFFE7D3DE)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.rosePrimary,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(46),
                            ),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Save Contact'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFFFF7FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.rosePrimary.withAlpha(120)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.redPrimary),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.redPrimary),
      ),
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String text;

  const _InputLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _DeviceContactPickerSheet extends StatefulWidget {
  final List<_DeviceContactOption> contacts;

  const _DeviceContactPickerSheet({required this.contacts});

  @override
  State<_DeviceContactPickerSheet> createState() =>
      _DeviceContactPickerSheetState();
}

class _DeviceContactPickerSheetState extends State<_DeviceContactPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lowerQuery = _search.toLowerCase();
    final filteredContacts = widget.contacts.where((contact) {
      if (lowerQuery.isEmpty) return true;
      return contact.name.toLowerCase().contains(lowerQuery) ||
          contact.phoneNumber.toLowerCase().contains(lowerQuery);
    }).toList(growable: false);

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.78;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomPadding),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: maxHeight,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 34,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE7D3DE),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.contacts_rounded,
                        color: AppColors.rosePrimary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select From Contacts',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _search = value.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by name or number',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFFFF7FB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: filteredContacts.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'No matching contacts found.',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: filteredContacts.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final contact = filteredContacts[index];
                          return InkWell(
                            onTap: () => Navigator.of(context).pop(contact),
                            borderRadius: BorderRadius.circular(14),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7FB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.rosePrimary.withAlpha(35),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        AppColors.rosePrimary.withAlpha(24),
                                    child: Text(
                                      contact.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: AppColors.rosePrimary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          contact.name,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          contact.phoneNumber,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
