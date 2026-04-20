import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/fake_call_service.dart';
import 'trusted_contact.dart';
import 'trusted_contacts_store.dart';
import 'trusted_contacts_ui.dart';
import 'women_profile_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Local design tokens  (light-mode only, extends AppColors without editing it)
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _T {
  // Surfaces
  static const Color pageBg       = Color(0xFFFBF6F9);   // warm near-white
  static const Color card         = Color(0xFFFFFFFF);
  static const Color cardBorder   = Color(0xFFF0E0EA);
  static const Color headerBg     = Color(0xFFFFFFFF);

  // SOS
  static const Color sosCore      = Color(0xFFD32F2F);
  static const Color sosDeep      = Color(0xFFB71C1C);
  static const Color sosRing1     = Color(0x26D32F2F);   // 15 %
  static const Color sosRing2     = Color(0x14D32F2F);   // 8 %

  // Action cards  [surface, icon-bg, icon-fg]
  static const List<List<Color>> act = [
    [Color(0xFFEFF6FF), Color(0xFFDCEEFD), Color(0xFF1565C0)], // Live Track
    [Color(0xFFF0FDF4), Color(0xFFD1FAE5), Color(0xFF15803D)], // Fake Call
    [Color(0xFFF5F3FF), Color(0xFFEDE9FE), Color(0xFF6D28D9)], // Record
    [Color(0xFFFFF7ED), Color(0xFFFFEDD5), Color(0xFFB45309)], // Safe Places
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Root scaffold
// ─────────────────────────────────────────────────────────────────────────────
class WomenDashboardScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const WomenDashboardScreen({super.key, required this.onLogout});

  @override
  State<WomenDashboardScreen> createState() => _WomenDashboardScreenState();
}

class _WomenDashboardScreenState extends State<WomenDashboardScreen> {
  int _selectedIndex = 0;
  int _homeRefreshToken = 0;
  final TrustedContactsStore _trustedContactsStore = const TrustedContactsStore();
  List<TrustedContact> _trustedContacts = const [];
  bool _isLoadingContacts = true;

  @override
  void initState() {
    super.initState();
    _loadTrustedContacts();
  }

  Future<void> _loadTrustedContacts() async {
    final contacts = await _trustedContactsStore.loadContacts();
    if (!mounted) return;
    setState(() {
      _trustedContacts = contacts;
      _isLoadingContacts = false;
    });
  }

  Future<void> _saveTrustedContacts(List<TrustedContact> contacts) async {
    await _trustedContactsStore.saveContacts(contacts);
    if (!mounted) return;
    setState(() => _trustedContacts = contacts);
  }

  Future<void> _addTrustedContact() async {
    final newContact = await showAddTrustedContactSheet(context);
    if (!mounted || newContact == null) return;

    final newPhone = normalizePhoneNumber(newContact.phoneNumber);
    final alreadyExists = _trustedContacts.any(
      (contact) => normalizePhoneNumber(contact.phoneNumber) == newPhone,
    );
    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This phone number is already in trusted contacts.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final updated = [..._trustedContacts, newContact];
    await _saveTrustedContacts(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${newContact.name} added to trusted contacts.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _removeTrustedContact(TrustedContact contact) async {
    final shouldRemove = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove contact?'),
            content: Text(
              'Remove ${contact.name} from your trusted contacts?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.redPrimary,
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldRemove) return;

    final updated = _trustedContacts
        .where((item) => item.id != contact.id)
        .toList(growable: false);
    await _saveTrustedContacts(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${contact.name} removed.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openContactsTab() {
    setState(() => _selectedIndex = 1);
  }

  void _openProfileTab() {
    setState(() => _selectedIndex = 3);
  }

  void _handleProfileUpdated(Map<String, dynamic> _) {
    setState(() {
      _homeRefreshToken++;
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _T.pageBg,
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeTab(
              key: ValueKey(_homeRefreshToken),
              onLogout: widget.onLogout,
              trustedContacts: _trustedContacts,
              isLoadingContacts: _isLoadingContacts,
              onAddContact: _addTrustedContact,
              onOpenContacts: _openContactsTab,
              onOpenProfile: _openProfileTab,
            ),
            TrustedContactsTab(
              contacts: _trustedContacts,
              isLoading: _isLoadingContacts,
              onAddContact: _addTrustedContact,
              onDeleteContact: _removeTrustedContact,
            ),
            const _MapTab(),
            WomenProfileTab(onProfileUpdated: _handleProfileUpdated),
          ],
        ),
        bottomNavigationBar: _BottomNav(
          selectedIndex: _selectedIndex,
          onChanged: (i) => setState(() => _selectedIndex = i),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _BottomNav({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.card,
        border: Border(top: BorderSide(color: _T.cardBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: GNav(
            rippleColor: AppColors.roseTint,
            hoverColor: AppColors.roseTint,
            gap: 6,
            activeColor: AppColors.rosePrimary,
            iconSize: 22,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            duration: const Duration(milliseconds: 250),
            tabBackgroundColor: AppColors.roseTint,
            tabBorderRadius: 14,
            color: AppColors.textSecondary,
            textStyle: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.rosePrimary,
            ),
            tabs: const [
              GButton(icon: Icons.home_rounded,   text: 'Home'),
              GButton(icon: Icons.group_rounded,  text: 'Contacts'),
              GButton(icon: Icons.map_rounded,    text: 'Routes'),
              GButton(icon: Icons.person_rounded, text: 'Profile'),
            ],
            selectedIndex: selectedIndex,
            onTabChange: onChanged,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Home Tab
// ─────────────────────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final VoidCallback onLogout;
  final List<TrustedContact> trustedContacts;
  final bool isLoadingContacts;
  final VoidCallback onAddContact;
  final VoidCallback onOpenContacts;
  final VoidCallback onOpenProfile;

  const _HomeTab({
    super.key,
    required this.onLogout,
    required this.trustedContacts,
    required this.isLoadingContacts,
    required this.onAddContact,
    required this.onOpenContacts,
    required this.onOpenProfile,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
  with TickerProviderStateMixin, WidgetsBindingObserver {
  static const MethodChannel _sosSetupChannel = MethodChannel('haven/sos_setup');
  static const MethodChannel _audioChunkChannel = MethodChannel('haven/audio_chunks');

  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;
  bool _isCheckingSosSetup = true;
  bool _isAccessibilityEnabled = false;
  bool _isNotificationEnabled = false;
  bool _isChunkRecording = false;
  bool _isAngryFatherModeEnabled = false;
  int _recordingElapsedMs = 0;
  String _recordingSaveDirectory = '';
  String _currentChunkPath = '';

  Timer? _recordingStatusTimer;

  late final AnimationController _pulse;
  late final AnimationController _hold;
  bool _sosActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadProfile();
    _refreshSosSetupStatus();
    _syncAudioRecordingState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _hold = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          setState(() => _sosActive = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _sosActive = false);
              _hold.reset();
            }
          });
        }
      });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _recordingStatusTimer?.cancel();
    _pulse.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSosSetupStatus();
      _syncAudioRecordingState();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final data = await AuthService.instance.getProfile();
      if (mounted) setState(() { _profile = data; _isLoadingProfile = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  Future<void> _refreshSosSetupStatus() async {
    if (!mounted) return;
    setState(() => _isCheckingSosSetup = true);

    bool accessibilityEnabled = false;
    bool notificationEnabled = false;

    try {
      accessibilityEnabled =
          await _sosSetupChannel.invokeMethod<bool>('isSosAccessibilityEnabled') ?? false;
    } catch (_) {
      accessibilityEnabled = false;
    }

    try {
      final status = await Permission.notification.status;
      notificationEnabled = status.isGranted;
    } catch (_) {
      notificationEnabled = false;
    }

    if (!mounted) return;
    setState(() {
      _isAccessibilityEnabled = accessibilityEnabled;
      _isNotificationEnabled = notificationEnabled;
      _isCheckingSosSetup = false;
    });
  }

  Future<void> _openAccessibilitySettings() async {
    bool opened = false;
    try {
      opened = await _sosSetupChannel.invokeMethod<bool>('openAccessibilitySettings') ?? false;
    } catch (_) {
      opened = false;
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Accessibility settings.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _requestNotifications() async {
    await Permission.notification.request();
    await _refreshSosSetupStatus();
  }

  Future<void> _syncAudioRecordingState() async {
    bool isRecording = false;
    int elapsedMs = 0;
    String saveDirectory = '';
    String currentChunkPath = '';

    try {
      final status = await _audioChunkChannel
          .invokeMapMethod<String, dynamic>('getChunkRecordingStatus');
      isRecording = (status?['isRecording'] as bool?) ?? false;
      elapsedMs = (status?['elapsedMs'] as num?)?.toInt() ?? 0;
      saveDirectory = (status?['saveDirectory'] as String?) ?? '';
      currentChunkPath = (status?['currentChunkPath'] as String?) ?? '';
    } catch (_) {
      isRecording = false;
    }

    if (!mounted) return;
    setState(() {
      _isChunkRecording = isRecording;
      _recordingElapsedMs = elapsedMs;
      _recordingSaveDirectory = saveDirectory;
      _currentChunkPath = currentChunkPath;
    });

    if (isRecording) {
      _startRecordingStatusTimer();
    } else {
      _stopRecordingStatusTimer();
    }
  }

  void _startRecordingStatusTimer() {
    if (_recordingStatusTimer?.isActive ?? false) {
      return;
    }
    _recordingStatusTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncAudioRecordingState(),
    );
  }

  void _stopRecordingStatusTimer() {
    _recordingStatusTimer?.cancel();
    _recordingStatusTimer = null;
  }

  String _formatRecordingDuration(int totalMs) {
    final totalSeconds = (totalMs / 1000).floor();
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) {
      final hh = hours.toString().padLeft(2, '0');
      return '$hh:$mm:$ss';
    }
    return '$mm:$ss';
  }

  Future<void> _toggleAudioChunkRecording() async {
    if (_isChunkRecording) {
      bool stopped = false;
      try {
        stopped = await _audioChunkChannel.invokeMethod<bool>('stopChunkRecording') ?? false;
      } catch (_) {
        stopped = false;
      }

      if (!mounted) return;
      if (stopped) {
        await _syncAudioRecordingState();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio recording stopped.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not stop audio recording.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone permission is required to record audio.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    bool started = false;
    try {
      started = await _audioChunkChannel.invokeMethod<bool>('startChunkRecording') ?? false;
    } catch (_) {
      started = false;
    }

    if (!mounted) return;
    if (started) {
      await _syncAudioRecordingState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio recording started. Splits into 20-second chunks on stop.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start audio recording.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openRecordingsScreen() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _RecordingsScreen(saveDirectory: _recordingSaveDirectory),
      ),
    );
    await _syncAudioRecordingState();
  }

  Future<void> _handleNormalFakeCall() async {
    final settings = await FakeCallService.loadSettings();
    final scheduled = await FakeCallService.scheduleNormalFakeCall(settings);
    if (!mounted) return;

    if (scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Fake call scheduled in ${settings.normalDelaySeconds}s.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not schedule fake call.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleAngryFatherMode() async {
    if (_isAngryFatherModeEnabled) {
      final stopped = await FakeCallService.stopAngryFatherMode();
      if (!mounted) return;
      if (stopped) {
        setState(() => _isAngryFatherModeEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Angry father mode stopped.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final settings = await FakeCallService.loadSettings();
    final started = await FakeCallService.startAngryFatherMode(settings);
    if (!mounted) return;
    if (started) {
      setState(() => _isAngryFatherModeEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Angry father mode started: ${settings.angryRepeatCount} calls, every ${settings.angryDelaySeconds}s.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not start angry father mode.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareLocation() async {
    if (!mounted) return;
    
    // Check location permissions
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fetching location...')),
    );

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      final String mapUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final String message = 'I need help! Here is my current location: $mapUrl';

      if (widget.trustedContacts.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No trusted contacts to share location with.')),
        );
        return;
      }

      final List<String> phoneNumbers = widget.trustedContacts.map((c) {
        String num = c.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
        if (num.length == 10 && !num.startsWith('+')) {
          num = '+91$num'; // Append default country code for India
        }
        return num;
      }).toList();
      
      // WhatsApp does not support multiple comma-separated numbers in SMS intents well.
      // However, making sure they have the country code is the main issue.
      final String phonesStr = phoneNumbers.join(',');
      
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phonesStr,
        queryParameters: <String, String>{
          'body': message,
        },
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open SMS app')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _openFakeCallActionSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fake Calling',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Runs using your configured delays from Settings.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFFF0FDF4),
                leading: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF15803D)),
                title: const Text('Normal Fake Call'),
                subtitle: const Text('Single delayed call'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _handleNormalFakeCall();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: const Color(0xFFFFF7ED),
                leading: Icon(
                  _isAngryFatherModeEnabled ? Icons.pause_circle_filled : Icons.record_voice_over_rounded,
                  color: const Color(0xFFB45309),
                ),
                title: Text(
                  _isAngryFatherModeEnabled ? 'Stop Angry Father Mode' : 'Start Angry Father Mode',
                ),
                subtitle: const Text('Repeated delayed fake calls'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await _toggleAngryFatherMode();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _isProfileComplete {
    final profile = _profile;
    if (profile == null) return true;
    return AuthService.instance.isProfileComplete(profile);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final String name = _profile?['full_name'] ?? 'User';
    final String? photoUrl = _profile?['profile_photo_url'];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          _Header(
            topPad: topPad,
            name: name,
            photoUrl: photoUrl,
            isLoading: _isLoadingProfile,
            onLogout: widget.onLogout,
          ),
          SizedBox(
            height: h * 0.38,
            child: _SOSHero(
              pulse: _pulse,
              hold: _hold,
              active: _sosActive,
            ),
          ),
          _PrimarySecondaryRow(
            onFakeCallTap: _openFakeCallActionSheet,
            onShareLocationTap: _shareLocation,
            isAngryFatherModeEnabled: _isAngryFatherModeEnabled,
          ),
          _SosSetupStatusCard(
            isLoading: _isCheckingSosSetup,
            accessibilityEnabled: _isAccessibilityEnabled,
            notificationEnabled: _isNotificationEnabled,
            onRefresh: _refreshSosSetupStatus,
            onOpenAccessibilitySettings: _openAccessibilitySettings,
            onRequestNotifications: _requestNotifications,
          ),
          if (!_isLoadingProfile && !_isProfileComplete)
            _IncompleteProfilePrompt(onTap: widget.onOpenProfile),
          _ScrollZone(
            trustedContacts: widget.trustedContacts,
            isLoadingContacts: widget.isLoadingContacts,
            onAddContact: widget.onAddContact,
            onOpenContacts: widget.onOpenContacts,
            onRecordAudioTap: _toggleAudioChunkRecording,
            onOpenRecordings: _openRecordingsScreen,
            isChunkRecording: _isChunkRecording,
            recordingElapsedLabel: _formatRecordingDuration(_recordingElapsedMs),
            recordingSaveDirectory: _recordingSaveDirectory,
            currentChunkPath: _currentChunkPath,
          ),
          SizedBox(height: bottomPad + 16),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Header
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final double topPad;
  final String name;
  final String? photoUrl;
  final bool isLoading;
  final VoidCallback onLogout;

  const _Header({
    required this.topPad,
    required this.name,
    required this.photoUrl,
    required this.isLoading,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _T.headerBg,
      padding: EdgeInsets.only(
        top: topPad + 10,
        bottom: 12,
        left: 20,
        right: 16,
      ),
      child: Row(
        children: [
          _Avatar(photoUrl: photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: isLoading
                ? _Shimmer(width: 120, height: 14)
                : RichText(
                    text: TextSpan(
                      style: const TextStyle(color: AppColors.textPrimary),
                      children: [
                        TextSpan(
                          text: 'Hi, $name',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const TextSpan(text: '  👋'),
                      ],
                    ),
                  ),
          ),
          _HeaderBtn(icon: Icons.notifications_outlined, onTap: () {}),
          const SizedBox(width: 6),
          _HeaderBtn(icon: Icons.logout_rounded, onTap: onLogout),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoUrl;
  const _Avatar({this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.roseLight, width: 2),
      ),
      child: ClipOval(
        child: photoUrl != null
            ? Image.network(photoUrl!, fit: BoxFit.cover)
            : Container(
                color: AppColors.roseTint,
                child: const Icon(Icons.person_rounded,
                    color: AppColors.rosePrimary, size: 20),
              ),
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: _T.pageBg,
          shape: BoxShape.circle,
          border: Border.all(color: _T.cardBorder),
        ),
        child: Icon(icon, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. SOS Hero
// ─────────────────────────────────────────────────────────────────────────────
class _SOSHero extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController hold;
  final bool active;
  const _SOSHero({required this.pulse, required this.hold, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          active
              ? '🚨  Emergency alert sent!'
              : 'Press & hold 3 s in an emergency',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: active ? AppColors.redPrimary : AppColors.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 22),
        _SOSButtonCore(pulse: pulse, hold: hold, active: active),
      ],
    );
  }
}

class _SOSButtonCore extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController hold;
  final bool active;
  const _SOSButtonCore({required this.pulse, required this.hold, required this.active});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        HapticFeedback.mediumImpact();
        hold.forward();
      },
      onLongPressEnd: (_) {
        if (hold.status != AnimationStatus.completed) hold.reverse();
      },
      onLongPressCancel: () => hold.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([pulse, hold]),
        builder: (context, _) {
          final double pv = pulse.value;
          final double hv = hold.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer aura — breathes with pulse
              Container(
                width: 182 + (pv * 14),
                height: 182 + (pv * 14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.sosRing2.withAlpha((pv * 50).toInt()),
                ),
              ),
              // Mid ring
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.sosRing1.withAlpha((pv * 70 + 20).toInt()),
                ),
              ),
              // Core
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: active
                        ? [const Color(0xFFEF5350), _T.sosDeep]
                        : [
                            Color.lerp(
                                const Color(0xFFEF5350),
                                const Color(0xFFE53935),
                                hv)!,
                            Color.lerp(_T.sosCore, _T.sosDeep, hv)!,
                          ],
                    center: const Alignment(-0.3, -0.3),
                    radius: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _T.sosCore
                          .withAlpha((70 + (hv * 110).toInt())),
                      blurRadius: 22 + (hv * 18),
                      spreadRadius: 2 + (hv * 6),
                    ),
                    const BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (hv > 0)
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: CircularProgressIndicator(
                          value: hv,
                          strokeWidth: 4,
                          color: Colors.white.withAlpha(200),
                          backgroundColor: Colors.transparent,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SOS',
                          style: const TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 4,
                            height: 1,
                          ),
                        ),
                        if (hv > 0.04) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${((1 - hv) * 3).ceil()}s',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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

// ─────────────────────────────────────────────────────────────────────────────
// 4. Primary Secondary Actions  (Share Location + Fake Call)
// ─────────────────────────────────────────────────────────────────────────────
class _PrimarySecondaryRow extends StatelessWidget {
  final VoidCallback onFakeCallTap;
  final VoidCallback onShareLocationTap;
  final bool isAngryFatherModeEnabled;

  const _PrimarySecondaryRow({
    required this.onFakeCallTap,
    required this.onShareLocationTap,
    required this.isAngryFatherModeEnabled,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: _PillAction(
              icon: Icons.near_me_rounded,
              label: 'Share Location',
              color: _T.act[0][2],
              bg: _T.act[0][0],
              onTap: onShareLocationTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PillAction(
              icon: isAngryFatherModeEnabled
                  ? Icons.record_voice_over_rounded
                  : Icons.phone_in_talk_rounded,
              label: isAngryFatherModeEnabled ? 'Angry Mode On' : 'Fake Call',
              color: _T.act[1][2],
              bg: _T.act[1][0],
              onTap: onFakeCallTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _IncompleteProfilePrompt extends StatelessWidget {
  final VoidCallback onTap;

  const _IncompleteProfilePrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFD6A8)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your profile is incomplete. Tap to add missing details.',
                  style: TextStyle(
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Color(0xFF92400E)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SosSetupStatusCard extends StatelessWidget {
  final bool isLoading;
  final bool accessibilityEnabled;
  final bool notificationEnabled;
  final VoidCallback onRefresh;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onRequestNotifications;

  const _SosSetupStatusCard({
    required this.isLoading,
    required this.accessibilityEnabled,
    required this.notificationEnabled,
    required this.onRefresh,
    required this.onOpenAccessibilitySettings,
    required this.onRequestNotifications,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBFDBFE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings_accessibility_rounded, color: Color(0xFF1D4ED8)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'SOS Setup Status',
                    style: TextStyle(
                      color: Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                InkWell(
                  onTap: onRefresh,
                  borderRadius: BorderRadius.circular(14),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF1D4ED8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (isLoading)
              const Text(
                'Checking service and permissions...',
                style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
              )
            else ...[
              _SetupStatusRow(
                label: 'Accessibility service',
                isEnabled: accessibilityEnabled,
              ),
              const SizedBox(height: 6),
              _SetupStatusRow(
                label: 'Notification permission',
                isEnabled: notificationEnabled,
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  final buttonWidth = (constraints.maxWidth - 8) / 2;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: buttonWidth,
                        child: OutlinedButton.icon(
                          onPressed: onOpenAccessibilitySettings,
                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                          label: const Text('Accessibility', style: TextStyle(fontSize: 12.5),),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1D4ED8),
                            side: const BorderSide(color: Color(0xFF93C5FD)),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: buttonWidth,
                        child: FilledButton.icon(
                          onPressed: notificationEnabled ? null : onRequestNotifications,
                          icon: const Icon(Icons.notifications_active_rounded, size: 16),
                          label: Text(notificationEnabled ? 'Allowed' : 'Allow'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            disabledBackgroundColor: const Color(0xFF93C5FD),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupStatusRow extends StatelessWidget {
  final String label;
  final bool isEnabled;

  const _SetupStatusRow({required this.label, required this.isEnabled});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isEnabled ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          size: 18,
          color: isEnabled ? const Color(0xFF15803D) : const Color(0xFFB45309),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$label: ${isEnabled ? 'Enabled' : 'Not enabled'}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF334155),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _PillAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _PillAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });
  @override
  State<_PillAction> createState() => _PillActionState();
}

class _PillActionState extends State<_PillAction>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
  late final Animation<double> _scale =
      Tween<double>(begin: 1, end: 0.96).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeOut),
  );

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) { _c.forward(); HapticFeedback.selectionClick(); },
      onTapUp: (_) { _c.reverse(); widget.onTap(); },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: widget.bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.color.withAlpha(40)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.color, size: 20),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Scroll Zone  (tertiary — requires intentional scrolling)
// ─────────────────────────────────────────────────────────────────────────────
class _ScrollZone extends StatelessWidget {
  final List<TrustedContact> trustedContacts;
  final bool isLoadingContacts;
  final VoidCallback onAddContact;
  final VoidCallback onOpenContacts;
  final VoidCallback onRecordAudioTap;
  final VoidCallback onOpenRecordings;
  final bool isChunkRecording;
  final String recordingElapsedLabel;
  final String recordingSaveDirectory;
  final String currentChunkPath;

  const _ScrollZone({
    required this.trustedContacts,
    required this.isLoadingContacts,
    required this.onAddContact,
    required this.onOpenContacts,
    required this.onRecordAudioTap,
    required this.onOpenRecordings,
    required this.isChunkRecording,
    required this.recordingElapsedLabel,
    required this.recordingSaveDirectory,
    required this.currentChunkPath,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        const _SectionLabel('More Tools'),
        const SizedBox(height: 12),
        _TertiaryGrid(
          onRecordAudioTap: onRecordAudioTap,
          isChunkRecording: isChunkRecording,
          recordingElapsedLabel: recordingElapsedLabel,
        ),
        const SizedBox(height: 10),
        _RecordingStatePanel(
          isChunkRecording: isChunkRecording,
          recordingElapsedLabel: recordingElapsedLabel,
          recordingSaveDirectory: recordingSaveDirectory,
          currentChunkPath: currentChunkPath,
          onOpenRecordings: onOpenRecordings,
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Trusted Contacts'),
        const SizedBox(height: 12),
        TrustedContactsPreview(
          contacts: trustedContacts,
          isLoading: isLoadingContacts,
          onAddContact: onAddContact,
          onOpenContacts: onOpenContacts,
        ),
        const SizedBox(height: 24),
        const _SectionLabel('Safety Tip'),
        const SizedBox(height: 12),
        const _TipCard(),
        ],
      ),
    );
  }
}

// ── Section label
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 15,
          decoration: BoxDecoration(
            color: AppColors.rosePrimary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ],
    );
  }
}

// ── Tertiary 2-col grid  (Record Audio + Safe Places)
class _TertiaryGrid extends StatelessWidget {
  final VoidCallback onRecordAudioTap;
  final bool isChunkRecording;
  final String recordingElapsedLabel;

  const _TertiaryGrid({
    required this.onRecordAudioTap,
    required this.isChunkRecording,
    required this.recordingElapsedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _TertiaryCard(
              icon: isChunkRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
              title: isChunkRecording ? 'Stop Recording' : 'Record Audio',
              sub: isChunkRecording
                  ? 'Recording • $recordingElapsedLabel'
                  : 'Start covert background capture',
              palette: _T.act[2],
              onTap: onRecordAudioTap,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 6),
            child: _TertiaryCard(
              icon: Icons.shield_rounded,
              title: 'Safe Places',
              sub: 'Nearby verified safe zones',
              palette: _T.act[3],
              onTap: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _RecordingStatePanel extends StatelessWidget {
  final bool isChunkRecording;
  final String recordingElapsedLabel;
  final String recordingSaveDirectory;
  final String currentChunkPath;
  final VoidCallback onOpenRecordings;

  const _RecordingStatePanel({
    required this.isChunkRecording,
    required this.recordingElapsedLabel,
    required this.recordingSaveDirectory,
    required this.currentChunkPath,
    required this.onOpenRecordings,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isChunkRecording ? const Color(0xFF15803D) : const Color(0xFF64748B);
    final statusText = isChunkRecording ? 'ON' : 'OFF';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.multitrack_audio_rounded, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Text(
                'Recording: $statusText',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
              const Spacer(),
              Text(
                recordingElapsedLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Save folder: ${recordingSaveDirectory.isEmpty ? 'Not available yet' : recordingSaveDirectory}',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          if (isChunkRecording && currentChunkPath.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Current chunk: $currentChunkPath',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onOpenRecordings,
              icon: const Icon(Icons.library_music_rounded, size: 16),
              label: const Text('View Recordings'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF1D4ED8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecordingsScreen extends StatefulWidget {
  final String saveDirectory;

  const _RecordingsScreen({required this.saveDirectory});

  @override
  State<_RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<_RecordingsScreen> {
  static const MethodChannel _audioChunkChannel = MethodChannel('haven/audio_chunks');
  static const String _cleanupPreferenceKey = 'recordings_cleanup_label';
  static const Map<String, int?> _cleanupOptions = {
    'Off': null,
    '1 hour': 3600,
    '6 hours': 21600,
    '24 hours': 86400,
    '3 days': 259200,
    '7 days': 604800,
  };

  List<FileSystemEntity> _files = const [];
  bool _isLoading = true;
  String? _playingPath;
  bool _selectionMode = false;
  final Set<String> _selectedPaths = <String>{};
  String _cleanupLabel = 'Off';

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLabel = prefs.getString(_cleanupPreferenceKey);
    if (savedLabel != null && _cleanupOptions.containsKey(savedLabel)) {
      _cleanupLabel = savedLabel;
    }
    await _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (widget.saveDirectory.isEmpty) {
      if (!mounted) return;
      setState(() {
        _files = const [];
        _isLoading = false;
      });
      return;
    }

    final dir = Directory(widget.saveDirectory);
    if (!await dir.exists()) {
      if (!mounted) return;
      setState(() {
        _files = const [];
        _isLoading = false;
      });
      return;
    }

    await _runAutoCleanup(dir);

    final entities = await dir.list().where((e) => e.path.endsWith('.m4a')).toList();
    entities.sort((a, b) {
      final aModified = File(a.path).lastModifiedSync();
      final bModified = File(b.path).lastModifiedSync();
      return bModified.compareTo(aModified);
    });

    if (!mounted) return;
    setState(() {
      _files = entities;
      _selectedPaths.removeWhere((path) => !_files.any((f) => f.path == path));
      if (_selectedPaths.isEmpty) {
        _selectionMode = false;
      }
      _isLoading = false;
    });
  }

  Future<void> _runAutoCleanup(Directory dir) async {
    final retentionSeconds = _cleanupOptions[_cleanupLabel];
    if (retentionSeconds == null) {
      return;
    }

    final cutoff = DateTime.now().subtract(Duration(seconds: retentionSeconds));
    final entities = await dir.list().where((e) => e.path.endsWith('.m4a')).toList();
    for (final entity in entities) {
      final file = File(entity.path);
      final modifiedAt = await file.lastModified();
      if (modifiedAt.isBefore(cutoff)) {
        await file.delete();
      }
    }
  }

  Future<void> _togglePlayback(String path) async {
    if (_playingPath == path) {
      await _stopPlayback();
      if (!mounted) return;
      setState(() => _playingPath = null);
      return;
    }

    final started = await _audioChunkChannel
            .invokeMethod<bool>('playChunkAudio', <String, dynamic>{'path': path}) ??
        false;
    if (!mounted) return;
    if (started) {
      setState(() => _playingPath = path);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not play this recording.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stopPlayback() async {
    try {
      await _audioChunkChannel.invokeMethod<bool>('stopChunkAudio');
    } catch (_) {
      // ignore
    }
  }

  Future<void> _deleteFile(String path) async {
    if (_playingPath == path) {
      await _stopPlayback();
      if (mounted) {
        setState(() => _playingPath = null);
      }
    }

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await _loadFiles();
  }

  Future<void> _toggleSelection(String path) async {
    setState(() {
      _selectionMode = true;
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
      if (_selectedPaths.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedPaths.isEmpty) return;

    final count = _selectedPaths.length;
    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete recordings?'),
            content: Text('Delete $count selected recording(s)?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.redPrimary),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;

    await _stopPlayback();
    for (final path in _selectedPaths.toList()) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }

    if (!mounted) return;
    setState(() {
      _playingPath = null;
      _selectedPaths.clear();
      _selectionMode = false;
    });
    await _loadFiles();
  }

  Future<void> _updateCleanupPreference(String label) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cleanupPreferenceKey, label);
    if (!mounted) return;
    setState(() => _cleanupLabel = label);
    await _loadFiles();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = _selectionMode
        ? '${_selectedPaths.length} selected'
        : 'Recorded Chunks';

    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
        actions: [
          if (_selectionMode)
            IconButton(
              onPressed: _deleteSelected,
              icon: const Icon(Icons.delete_rounded),
            ),
          if (_selectionMode)
            IconButton(
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedPaths.clear();
                });
              },
              icon: const Icon(Icons.close_rounded),
            ),
          IconButton(
            onPressed: _loadFiles,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? const Center(
                  child: Text(
                    'No recordings found yet.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _files.length + 1,
                  separatorBuilder: (_, index) => index == 0
                      ? const SizedBox(height: 14)
                      : const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Auto cleanup',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            DropdownButton<String>(
                              value: _cleanupLabel,
                              underline: const SizedBox.shrink(),
                              items: _cleanupOptions.keys
                                  .map((label) => DropdownMenuItem<String>(
                                        value: label,
                                        child: Text(label),
                                      ))
                                  .toList(growable: false),
                              onChanged: (next) {
                                if (next == null) return;
                                _updateCleanupPreference(next);
                              },
                            ),
                          ],
                        ),
                      );
                    }

                    final file = File(_files[index - 1].path);
                    final stat = file.statSync();
                    final isPlaying = _playingPath == file.path;
                    final isSelected = _selectedPaths.contains(file.path);
                    final fileName = file.uri.pathSegments.last;

                    return Container(
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF93C5FD) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: ListTile(
                        onTap: () {
                          if (_selectionMode) {
                            _toggleSelection(file.path);
                          } else {
                            _togglePlayback(file.path);
                          }
                        },
                        onLongPress: () => _toggleSelection(file.path),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        leading: _selectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (_) => _toggleSelection(file.path),
                              )
                            : IconButton(
                                onPressed: () => _togglePlayback(file.path),
                                icon: Icon(
                                  isPlaying
                                      ? Icons.stop_circle_rounded
                                      : Icons.play_circle_fill_rounded,
                                  color: const Color(0xFF1D4ED8),
                                  size: 30,
                                ),
                              ),
                        title: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${_formatBytes(stat.size)} • ${stat.modified}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                        trailing: _selectionMode
                            ? null
                            : IconButton(
                                onPressed: () => _deleteFile(file.path),
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: AppColors.redPrimary,
                                ),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _TertiaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final List<Color> palette;
  final VoidCallback onTap;
  const _TertiaryCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette[0],
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette[2].withAlpha(35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: palette[1],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: palette[2], size: 20),
            ),
            const SizedBox(height: 12),
            Text(title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.1,
                )),
            const SizedBox(height: 4),
            Text(sub,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.4,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Safety Tip Card (tappable, animated)
const _kTips = [
  (Icons.psychology_rounded, 'Trust Your Instincts',
      'If something feels wrong, it probably is. Leave without explanation.'),
  (Icons.route_rounded, 'Share Your Route',
      'Send your live route to a contact before travelling solo.'),
  (Icons.visibility_rounded, 'Stay Present',
      'Limit phone use in unfamiliar or isolated areas.'),
];

class _TipCard extends StatefulWidget {
  const _TipCard();
  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = _kTips[_i];
    return GestureDetector(
      onTap: () => setState(() => _i = (_i + 1) % _kTips.length),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(_i),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _T.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _T.cardBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x08000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.roseTint,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AppColors.rosePrimary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.1,
                        )),
                  ),
                  Text(
                    '${_i + 1} / ${_kTips.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.55,
                  )),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.touch_app_rounded,
                      size: 12,
                      color: AppColors.textSecondary.withAlpha(100)),
                  const SizedBox(width: 5),
                  Text('Tap for next tip',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary.withAlpha(100),
                      )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utility: Shimmer placeholder
// ─────────────────────────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final double width;
  final double height;
  const _Shimmer({required this.width, required this.height});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(
            const Color(0xFFEEE0E8),
            const Color(0xFFF9F0F5),
            _c.value,
          ),
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder tabs
// ─────────────────────────────────────────────────────────────────────────────
class _MapTab extends StatelessWidget {
  const _MapTab();
  @override
  Widget build(BuildContext context) =>
      const _TabPlaceholder(icon: Icons.map_rounded, label: 'Safe Routes');
}

class _TabPlaceholder extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TabPlaceholder({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.roseTint,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.rosePrimary, size: 30),
            ),
            const SizedBox(height: 14),
            Text(label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 6),
            const Text('Coming soon',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                )),
          ],
        ),
      ),
    );
  }
}