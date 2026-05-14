import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/fake_call_service.dart';
import '../../../core/services/sos_service.dart';
import 'trusted_contact.dart';
import 'trusted_contacts_store.dart';
import 'safe_routes_tab.dart';
import 'trusted_contacts_ui.dart';
import 'women_profile_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design Tokens  — "Haven" — Luxury Safety Palette
// ─────────────────────────────────────────────────────────────────────────────
abstract final class _T {
  // ── Surfaces
  static const Color pageBg       = Color(0xFFFDF4F8);   // warm blush
  static const Color pageBg2      = Color(0xFFF7EBF3);   // deeper blush accent
  static const Color card         = Color(0xFFFFFFFF);
  static const Color cardBorder   = Color(0xFFF2D9EA);
  static const Color cardShadow   = Color(0x12A0145A);
  static const Color headerBg     = Color(0xFFFFFFFF);
  static const Color glassWhite   = Color(0xF2FFFFFF);   // frosted glass surface

  // ── Brand
  static const Color roseDeep     = Color(0xFFA0145A);   // deep magenta rose
  static const Color roseMid      = Color(0xFFCC2E7A);   // brand primary
  static const Color roseSoft     = Color(0xFFEF6FA8);   // lighter accent
  static const Color roseTint     = Color(0xFFFCE8F3);
  static const Color rosePale     = Color(0xFFFFF0F8);

  // ── SOS
  static const Color sosCore      = Color(0xFFD32F2F);
  static const Color sosDeep      = Color(0xFFB71C1C);
  static const Color sosBright    = Color(0xFFFF5252);
  static const Color sosRing1     = Color(0x30D32F2F);
  static const Color sosRing2     = Color(0x16D32F2F);
  static const Color sosRing3     = Color(0x09D32F2F);

  // ── Action cards  [surface, icon-bg, icon-fg, gradient-start, gradient-end]
  // Live Track
  static const List<Color> actBlue = [
    Color(0xFFEFF6FF), Color(0xFFD4E9FF), Color(0xFF1565C0),
    Color(0xFFEFF6FF), Color(0xFFDBEEFF),
  ];
  // Fake Call
  static const List<Color> actGreen = [
    Color(0xFFF0FDF4), Color(0xFFC8F0D8), Color(0xFF166534),
    Color(0xFFF0FDF4), Color(0xFFD6FAE8),
  ];
  // Record
  static const List<Color> actPurple = [
    Color(0xFFF5F0FF), Color(0xFFE4D8FF), Color(0xFF5B21B6),
    Color(0xFFF5F0FF), Color(0xFFEDE5FF),
  ];
  // Safe Places
  static const List<Color> actAmber = [
    Color(0xFFFFFBEB), Color(0xFFFFE9C0), Color(0xFF92400E),
    Color(0xFFFFFBEB), Color(0xFFFFF0CC),
  ];

  // ── Utility
  static const Color success      = Color(0xFF15803D);
  static const Color warning      = Color(0xFFB45309);
  static const Color info         = Color(0xFF1D4ED8);
  static const Color textPrimary  = Color(0xFF1A0A12);
  static const Color textSec      = Color(0xFF7A5068);
  static const Color textMuted    = Color(0xFFB89AAC);

  // ── Gradients
  static const LinearGradient headerGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF0F8)],
  );
  static const LinearGradient heroBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFDF4F8), Color(0xFFF7EBF3)],
  );
  static const LinearGradient roseGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFCC2E7A), Color(0xFFA0145A)],
  );
  static const LinearGradient alertGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF6B6B), Color(0xFFD32F2F)],
  );
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
            content: Text('Remove ${contact.name} from your trusted contacts?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.redPrimary),
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

  void _openContactsTab()  => setState(() => _selectedIndex = 1);
  void _openRoutesTab()    => setState(() => _selectedIndex = 2);
  void _openProfileTab()   => setState(() => _selectedIndex = 3);

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
              onOpenRoutes: _openRoutesTab,
              onOpenProfile: _openProfileTab,
            ),
            TrustedContactsTab(
              contacts: _trustedContacts,
              isLoading: _isLoadingContacts,
              onAddContact: _addTrustedContact,
              onDeleteContact: _removeTrustedContact,
            ),
            const SafeRoutesTab(),
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
// Bottom Navigation — frosted glass with gradient active pill
// ─────────────────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  const _BottomNav({required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFAFD), Color(0xFFFFFFFF)],
        ),
        border: Border(
          top: BorderSide(color: _T.cardBorder.withAlpha(180), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: _T.roseMid.withAlpha(14),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: GNav(
            rippleColor: _T.roseTint,
            hoverColor: _T.roseTint,
            gap: 6,
            activeColor: _T.roseMid,
            iconSize: 22,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            duration: const Duration(milliseconds: 280),
            tabBackgroundColor: _T.roseTint,
            tabBorderRadius: 16,
            color: _T.textSec,
            textStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _T.roseMid,
              letterSpacing: 0.1,
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
  final VoidCallback onOpenRoutes;
  final VoidCallback onOpenProfile;

  const _HomeTab({
    super.key,
    required this.onLogout,
    required this.trustedContacts,
    required this.isLoadingContacts,
    required this.onAddContact,
    required this.onOpenContacts,
    required this.onOpenRoutes,
    required this.onOpenProfile,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const Duration _sosChunkDuration = Duration(seconds: 20);
  static const Duration _sosStatePollInterval = Duration(seconds: 8);
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
  bool _isSosAudioStreaming = false;

  final AudioRecorder _sosAudioRecorder = AudioRecorder();
  Timer? _sosChunkTimer;
  String? _activeSosChunkPath;
  int _sosChunkIndex = 0;
  bool _isSosChunkUploadInFlight = false;

  Timer? _recordingStatusTimer;
  Timer? _sosStateTimer;
  bool _isSosStateCheckInFlight = false;

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
    _startSosStateWatch();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _hold = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addStatusListener((s) async {
        if (s == AnimationStatus.completed) {
          HapticFeedback.heavyImpact();
          setState(() => _sosActive = true);
          try {
            await SosService.instance.triggerSos();
            await _startSosAudioStreaming();
          } catch (e) {
            debugPrint('Error triggering SOS: $e');
          }
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
    _sosStateTimer?.cancel();
    _stopSosAudioStreaming();
    _recordingStatusTimer?.cancel();
    _sosChunkTimer?.cancel();
    _sosAudioRecorder.dispose();
    _pulse.dispose();
    _hold.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshSosSetupStatus();
      _syncAudioRecordingState();
      _checkSosStateAndEnforceRecording();
    }
  }

  void _startSosStateWatch() {
    _sosStateTimer?.cancel();
    _sosStateTimer = Timer.periodic(_sosStatePollInterval, (_) {
      _checkSosStateAndEnforceRecording();
    });
    _checkSosStateAndEnforceRecording();
  }

  Future<void> _checkSosStateAndEnforceRecording() async {
    if (_isSosStateCheckInFlight) return;
    _isSosStateCheckInFlight = true;
    try {
      final Map<String, dynamic> stateData = await SosService.instance.getSosState();
      final String state = (stateData['state'] ?? '').toString().trim().toLowerCase();
      if (state == 'normal') await _forceStopBackgroundVoiceRecording();
    } catch (_) {}
    finally { _isSosStateCheckInFlight = false; }
  }

  Future<void> _forceStopBackgroundVoiceRecording() async {
    bool needsSync = false;
    if (_isSosAudioStreaming) {
      await _stopSosAudioStreaming(uploadFinalChunk: false);
      needsSync = true;
    }
    final bool shouldStopChunkRecording =
        _isChunkRecording || await _audioChunkChannel.invokeMethod<bool>('isChunkRecording') == true;
    if (shouldStopChunkRecording) {
      try { await _audioChunkChannel.invokeMethod<bool>('stopChunkRecording'); } catch (_) {}
      needsSync = true;
    }
    if (needsSync && mounted) await _syncAudioRecordingState();
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
    try { accessibilityEnabled = await _sosSetupChannel.invokeMethod<bool>('isSosAccessibilityEnabled') ?? false; } catch (_) {}
    try {
      final status = await Permission.notification.status;
      notificationEnabled = status.isGranted;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isAccessibilityEnabled = accessibilityEnabled;
      _isNotificationEnabled = notificationEnabled;
      _isCheckingSosSetup = false;
    });
  }

  Future<void> _openAccessibilitySettings() async {
    bool opened = false;
    try { opened = await _sosSetupChannel.invokeMethod<bool>('openAccessibilitySettings') ?? false; } catch (_) {}
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Accessibility settings.'), behavior: SnackBarBehavior.floating),
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
      final status = await _audioChunkChannel.invokeMapMethod<String, dynamic>('getChunkRecordingStatus');
      isRecording = (status?['isRecording'] as bool?) ?? false;
      elapsedMs = (status?['elapsedMs'] as num?)?.toInt() ?? 0;
      saveDirectory = (status?['saveDirectory'] as String?) ?? '';
      currentChunkPath = (status?['currentChunkPath'] as String?) ?? '';
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isChunkRecording = isRecording;
      _recordingElapsedMs = elapsedMs;
      _recordingSaveDirectory = saveDirectory;
      _currentChunkPath = currentChunkPath;
    });
    if (isRecording) _startRecordingStatusTimer();
    else _stopRecordingStatusTimer();
  }

  Future<void> _startSosAudioStreaming() async {
    if (_isSosAudioStreaming) return;
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is required for SOS audio streaming.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    setState(() { _isSosAudioStreaming = true; _sosChunkIndex = 0; });
    try {
      await _beginSosChunkRecording();
      _sosChunkTimer = Timer.periodic(_sosChunkDuration, (_) async => _rotateAndUploadSosChunk());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS triggered. Live audio is now streaming to authorities.'), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      debugPrint('Failed to start SOS audio streaming: $e');
      await _stopSosAudioStreaming(uploadFinalChunk: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start SOS audio streaming: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _beginSosChunkRecording() async {
    final Directory tmpDir = await getTemporaryDirectory();
    final Directory sosDir = Directory('${tmpDir.path}/sos_live_audio');
    if (!await sosDir.exists()) await sosDir.create(recursive: true);
    final String path = '${sosDir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}_$_sosChunkIndex.m4a';
    _activeSosChunkPath = path;
    await _sosAudioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, bitRate: 64000),
      path: path,
    );
  }

  Future<void> _rotateAndUploadSosChunk({bool restartRecording = true}) async {
    if (!_isSosAudioStreaming || _isSosChunkUploadInFlight) return;
    _isSosChunkUploadInFlight = true;
    try {
      final String? chunkPath = await _sosAudioRecorder.stop();
      final String? pathToUpload = chunkPath ?? _activeSosChunkPath;
      if (pathToUpload != null) {
        final File chunkFile = File(pathToUpload);
        if (await chunkFile.exists() && await chunkFile.length() > 0) {
          await SosService.instance.uploadAudioChunk(_sosChunkIndex, pathToUpload);
          _sosChunkIndex += 1;
          await chunkFile.delete();
        }
      }
      if (_isSosAudioStreaming && restartRecording) await _beginSosChunkRecording();
    } catch (e) {
      debugPrint('SOS chunk upload failed: $e');
      if (_isSosAudioStreaming) {
        try { await _beginSosChunkRecording(); } catch (inner) { debugPrint('SOS chunk recorder restart failed: $inner'); }
      }
    } finally { _isSosChunkUploadInFlight = false; }
  }

  Future<void> _stopSosAudioStreaming({bool uploadFinalChunk = true}) async {
    if (!_isSosAudioStreaming) return;
    _sosChunkTimer?.cancel();
    _sosChunkTimer = null;
    if (!uploadFinalChunk) {
      _isSosAudioStreaming = false;
      try { await _sosAudioRecorder.stop(); } catch (_) {}
      return;
    }
    try { await _rotateAndUploadSosChunk(restartRecording: false); } catch (_) {}
    _isSosAudioStreaming = false;
  }

  void _startRecordingStatusTimer() {
    if (_recordingStatusTimer?.isActive ?? false) return;
    _recordingStatusTimer = Timer.periodic(const Duration(seconds: 1), (_) => _syncAudioRecordingState());
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
      try { stopped = await _audioChunkChannel.invokeMethod<bool>('stopChunkRecording') ?? false; } catch (_) {}
      if (!mounted) return;
      if (stopped) {
        await _syncAudioRecordingState();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio recording stopped.'), behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not stop audio recording.'), behavior: SnackBarBehavior.floating));
      }
      return;
    }
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone permission is required to record audio.'), behavior: SnackBarBehavior.floating));
      return;
    }
    bool started = false;
    try { started = await _audioChunkChannel.invokeMethod<bool>('startChunkRecording') ?? false; } catch (_) {}
    if (!mounted) return;
    if (started) {
      await _syncAudioRecordingState();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audio recording started. Splits into 20-second chunks on stop.'), behavior: SnackBarBehavior.floating));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start audio recording.'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _openRecordingsScreen() async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _RecordingsScreen(saveDirectory: _recordingSaveDirectory)),
    );
    await _syncAudioRecordingState();
  }

  Future<void> _handleNormalFakeCall() async {
    final settings = await FakeCallService.loadSettings();
    final scheduled = await FakeCallService.scheduleNormalFakeCall(settings);
    if (!mounted) return;
    if (scheduled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fake call scheduled in ${settings.normalDelaySeconds}s.'), behavior: SnackBarBehavior.floating));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not schedule fake call.'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _toggleAngryFatherMode() async {
    if (_isAngryFatherModeEnabled) {
      final stopped = await FakeCallService.stopAngryFatherMode();
      if (!mounted) return;
      if (stopped) {
        setState(() => _isAngryFatherModeEnabled = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Angry father mode stopped.'), behavior: SnackBarBehavior.floating));
      }
      return;
    }
    final settings = await FakeCallService.loadSettings();
    final started = await FakeCallService.startAngryFatherMode(settings);
    if (!mounted) return;
    if (started) {
      setState(() => _isAngryFatherModeEnabled = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Angry father mode started: ${settings.angryRepeatCount} calls, every ${settings.angryDelaySeconds}s.'), behavior: SnackBarBehavior.floating));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not start angry father mode.'), behavior: SnackBarBehavior.floating));
    }
  }

  Future<void> _shareLocation() async {
    if (!mounted) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fetching location...')));
    try {
      Position position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
      final String mapUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final String message = 'I need help! Here is my current location: $mapUrl';
      if (widget.trustedContacts.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No trusted contacts to share location with.')));
        return;
      }
      final List<String> phoneNumbers = widget.trustedContacts.map((c) {
        String num = c.phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
        if (num.length == 10 && !num.startsWith('+')) num = '+91$num';
        return num;
      }).toList();
      final String phonesStr = phoneNumbers.join(',');
      final Uri smsUri = Uri(scheme: 'sms', path: phonesStr, queryParameters: <String, String>{'body': message});
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open SMS app')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  Future<void> _openFakeCallActionSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      backgroundColor: _T.glassWhite,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(gradient: _T.roseGrad, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Fake Calling', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _T.textPrimary, letterSpacing: -0.3)),
                      Text('Uses your configured delays', style: TextStyle(fontSize: 12, color: _T.textSec)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SheetTile(
                icon: Icons.phone_in_talk_rounded,
                title: 'Normal Fake Call',
                subtitle: 'Single delayed call',
                color: _T.actGreen[2],
                bg: _T.actGreen[0],
                onTap: () async { Navigator.of(context).pop(); await _handleNormalFakeCall(); },
              ),
              const SizedBox(height: 10),
              _SheetTile(
                icon: _isAngryFatherModeEnabled ? Icons.pause_circle_filled : Icons.record_voice_over_rounded,
                title: _isAngryFatherModeEnabled ? 'Stop Angry Father Mode' : 'Start Angry Father Mode',
                subtitle: 'Repeated delayed fake calls',
                color: _T.actAmber[2],
                bg: _T.actAmber[0],
                onTap: () async { Navigator.of(context).pop(); await _toggleAngryFatherMode(); },
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
            child: _SOSHero(pulse: _pulse, hold: _hold, active: _sosActive),
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
            onOpenRoutes: widget.onOpenRoutes,
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

// ── Sheet tile helper (for fake call bottom sheet)
class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final Color bg;
  final VoidCallback onTap;
  const _SheetTile({required this.icon, required this.title, required this.subtitle, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: color.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _T.textPrimary)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: _T.textSec)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: _T.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Header — gradient background with floating avatar
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _T.headerGrad,
        border: Border(bottom: BorderSide(color: _T.cardBorder.withAlpha(120), width: 1)),
      ),
      padding: EdgeInsets.only(top: topPad + 12, bottom: 14, left: 20, right: 16),
      child: Row(
        children: [
          _Avatar(photoUrl: photoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: isLoading
                ? _Shimmer(width: 130, height: 14)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _greeting(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _T.roseMid, letterSpacing: 0.4),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _T.textPrimary, letterSpacing: -0.5),
                          ),
                          const SizedBox(width: 5),
                          const Text('👋', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                    ],
                  ),
          ),
          _HeaderBtn(icon: Icons.notifications_outlined, onTap: () {}),
          const SizedBox(width: 8),
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
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: _T.roseGrad,
        boxShadow: [BoxShadow(color: _T.roseMid.withAlpha(60), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ClipOval(
          child: photoUrl != null
              ? Image.network(photoUrl!, fit: BoxFit.cover)
              : Container(
                  decoration: const BoxDecoration(color: _T.roseTint),
                  child: const Icon(Icons.person_rounded, color: _T.roseMid, size: 22),
                ),
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
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _T.pageBg,
          shape: BoxShape.circle,
          border: Border.all(color: _T.cardBorder),
          boxShadow: [BoxShadow(color: _T.cardShadow, blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Icon(icon, size: 18, color: _T.textSec),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. SOS Hero — dramatic with multi-ring pulse
// ─────────────────────────────────────────────────────────────────────────────
class _SOSHero extends StatelessWidget {
  final AnimationController pulse;
  final AnimationController hold;
  final bool active;
  const _SOSHero({required this.pulse, required this.hold, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _T.heroBg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: active
                ? Container(
                    key: const ValueKey('active'),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: _T.alertGrad,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: _T.sosCore.withAlpha(70), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 6),
                        Text('🚨  Emergency alert sent!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                  )
                : Container(
                    key: const ValueKey('idle'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _T.roseTint,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _T.roseSoft.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, color: _T.roseMid, size: 13),
                        const SizedBox(width: 6),
                        Text('Hold 3 seconds in an emergency', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _T.roseMid)),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 28),
          _SOSButtonCore(pulse: pulse, hold: hold, active: active),
        ],
      ),
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
      onLongPressStart: (_) { HapticFeedback.mediumImpact(); hold.forward(); },
      onLongPressEnd: (_) { if (hold.status != AnimationStatus.completed) hold.reverse(); },
      onLongPressCancel: () => hold.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([pulse, hold]),
        builder: (context, _) {
          final double pv = pulse.value;
          final double hv = hold.value;

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outermost subtle aura
              Container(
                width: 210 + (pv * 16),
                height: 210 + (pv * 16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.sosRing3.withAlpha((pv * 35).toInt()),
                ),
              ),
              // Second ring
              Container(
                width: 188 + (pv * 10),
                height: 188 + (pv * 10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.sosRing2.withAlpha((pv * 55).toInt()),
                ),
              ),
              // Inner ring
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.sosRing1.withAlpha((pv * 75 + 20).toInt()),
                ),
              ),
              // Core button
              Container(
                width: 144,
                height: 144,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: active
                        ? [_T.sosBright, _T.sosDeep]
                        : [
                            Color.lerp(const Color(0xFFFF5252), const Color(0xFFEF5350), hv)!,
                            Color.lerp(_T.sosCore, _T.sosDeep, hv)!,
                          ],
                    center: const Alignment(-0.3, -0.35),
                    radius: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _T.sosCore.withAlpha((60 + (hv * 120).toInt())),
                      blurRadius: 24 + (hv * 20),
                      spreadRadius: 2 + (hv * 8),
                    ),
                    BoxShadow(
                      color: _T.sosCore.withAlpha(30),
                      blurRadius: 8,
                      spreadRadius: 0,
                      offset: const Offset(0, 6),
                    ),
                    const BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 5)),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Inner highlight
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 26,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(22),
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                      ),
                    ),
                    if (hv > 0)
                      SizedBox(
                        width: 144,
                        height: 144,
                        child: CircularProgressIndicator(
                          value: hv,
                          strokeWidth: 4.5,
                          color: Colors.white.withAlpha(210),
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
                            fontSize: 42,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 5,
                            height: 1,
                            shadows: [Shadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2))],
                          ),
                        ),
                        if (hv > 0.04) ...[
                          const SizedBox(height: 5),
                          Text(
                            '${((1 - hv) * 3).ceil()}s',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
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
// 4. Primary Actions — gradient pills
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: _GradientPillAction(
              icon: Icons.near_me_rounded,
              label: 'Share Location',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1976D2), Color(0xFF1565C0)],
              ),
              onTap: onShareLocationTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _GradientPillAction(
              icon: isAngryFatherModeEnabled
                  ? Icons.record_voice_over_rounded
                  : Icons.phone_in_talk_rounded,
              label: isAngryFatherModeEnabled ? 'Angry Mode On' : 'Fake Call',
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
              ),
              onTap: onFakeCallTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientPillAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;
  const _GradientPillAction({required this.icon, required this.label, required this.gradient, required this.onTap});

  @override
  State<_GradientPillAction> createState() => _GradientPillActionState();
}

class _GradientPillActionState extends State<_GradientPillAction> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
  late final Animation<double> _scale =
      Tween<double>(begin: 1, end: 0.96).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

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
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          decoration: BoxDecoration(
            gradient: widget.gradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: (widget.gradient.colors.first).withAlpha(70),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Colors.white, size: 19),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Incomplete Profile Prompt
// ─────────────────────────────────────────────────────────────────────────────
class _IncompleteProfilePrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _IncompleteProfilePrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFF8E1), Color(0xFFFFF3C4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFE082)),
            boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withAlpha(25), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Your profile is incomplete. Tap to add missing details.',
                  style: TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600, fontSize: 12, height: 1.4),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: Color(0xFF92400E), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOS Setup Status Card — refined glassmorphism
// ─────────────────────────────────────────────────────────────────────────────
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
    final bool allGood = accessibilityEnabled && notificationEnabled;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: allGood
                ? [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)]
                : [const Color(0xFFEFF6FF), const Color(0xFFDBEEFF)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: allGood ? const Color(0xFF86EFAC) : const Color(0xFF93C5FD),
          ),
          boxShadow: [
            BoxShadow(
              color: allGood ? const Color(0xFF16A34A).withAlpha(18) : const Color(0xFF3B82F6).withAlpha(18),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: allGood ? const Color(0xFF16A34A).withAlpha(25) : const Color(0xFF3B82F6).withAlpha(25),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    allGood ? Icons.shield_rounded : Icons.settings_accessibility_rounded,
                    color: allGood ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8),
                    size: 17,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    allGood ? 'SOS Ready' : 'SOS Setup Status',
                    style: TextStyle(
                      color: allGood ? const Color(0xFF166534) : const Color(0xFF1E3A8A),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onRefresh,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(180),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: allGood ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isLoading)
              Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: const Color(0xFF1D4ED8))),
                  const SizedBox(width: 10),
                  const Text('Checking permissions...', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                ],
              )
            else ...[
              _SetupStatusRow(label: 'Accessibility service', isEnabled: accessibilityEnabled),
              const SizedBox(height: 7),
              _SetupStatusRow(label: 'Notification permission', isEnabled: notificationEnabled),
              if (!allGood) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        SizedBox(
                          width: buttonWidth,
                          child: OutlinedButton.icon(
                            onPressed: onOpenAccessibilitySettings,
                            icon: const Icon(Icons.open_in_new_rounded, size: 14),
                            label: const Text('Accessibility', style: TextStyle(fontSize: 12)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1D4ED8),
                              side: const BorderSide(color: Color(0xFF93C5FD)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: buttonWidth,
                          child: FilledButton.icon(
                            onPressed: notificationEnabled ? null : onRequestNotifications,
                            icon: const Icon(Icons.notifications_active_rounded, size: 14),
                            label: Text(notificationEnabled ? 'Allowed' : 'Allow'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              disabledBackgroundColor: const Color(0xFF93C5FD),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
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
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: isEnabled ? const Color(0xFF16A34A).withAlpha(20) : const Color(0xFFB45309).withAlpha(20),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            isEnabled ? Icons.check_rounded : Icons.priority_high_rounded,
            size: 14,
            color: isEnabled ? const Color(0xFF15803D) : const Color(0xFFB45309),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '$label: ${isEnabled ? 'Enabled' : 'Not enabled'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. Scroll Zone
// ─────────────────────────────────────────────────────────────────────────────
class _ScrollZone extends StatelessWidget {
  final List<TrustedContact> trustedContacts;
  final bool isLoadingContacts;
  final VoidCallback onAddContact;
  final VoidCallback onOpenContacts;
  final VoidCallback onOpenRoutes;
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
    required this.onOpenRoutes,
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
            onOpenRoutesTap: onOpenRoutes,
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
          const SizedBox(height: 26),
          const _SectionLabel('Trusted Contacts'),
          const SizedBox(height: 12),
          TrustedContactsPreview(
            contacts: trustedContacts,
            isLoading: isLoadingContacts,
            onAddContact: onAddContact,
            onOpenContacts: onOpenContacts,
          ),
          const SizedBox(height: 26),
          const _SectionLabel('Safety Tip'),
          const SizedBox(height: 12),
          const _TipCard(),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            gradient: _T.roseGrad,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _T.textPrimary, letterSpacing: -0.3),
        ),
      ],
    );
  }
}

// ── Tertiary Grid
class _TertiaryGrid extends StatelessWidget {
  final VoidCallback onRecordAudioTap;
  final VoidCallback onOpenRoutesTap;
  final bool isChunkRecording;
  final String recordingElapsedLabel;

  const _TertiaryGrid({
    required this.onRecordAudioTap,
    required this.onOpenRoutesTap,
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
              sub: isChunkRecording ? '● Recording  $recordingElapsedLabel' : 'Start covert background capture',
              palette: _T.actPurple,
              isActive: isChunkRecording,
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
              palette: _T.actAmber,
              isActive: false,
              onTap: onOpenRoutesTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _TertiaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final List<Color> palette;
  final bool isActive;
  final VoidCallback onTap;

  const _TertiaryCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.palette,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette[3], palette[4]],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: palette[2].withAlpha(30)),
          boxShadow: [
            BoxShadow(
              color: palette[2].withAlpha(isActive ? 35 : 18),
              blurRadius: isActive ? 14 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [palette[1], palette[1].withAlpha(200)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: palette[2].withAlpha(30), blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Icon(icon, color: palette[2], size: 20),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _T.textPrimary, letterSpacing: -0.2),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? palette[2] : _T.textSec,
                height: 1.4,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recording State Panel
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _T.cardBorder),
        boxShadow: [BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isChunkRecording ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.multitrack_audio_rounded,
                  color: isChunkRecording ? _T.success : _T.textMuted,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isChunkRecording ? 'Recording Active' : 'Recording Off',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isChunkRecording ? _T.success : _T.textSec,
                  letterSpacing: -0.1,
                ),
              ),
              if (isChunkRecording) ...[
                const SizedBox(width: 8),
                _PulseDot(),
              ],
              const Spacer(),
              if (isChunkRecording)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    recordingElapsedLabel,
                    style: const TextStyle(fontSize: 12, color: _T.success, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Save folder: ${recordingSaveDirectory.isEmpty ? 'Not available yet' : recordingSaveDirectory}',
            style: const TextStyle(fontSize: 11, color: _T.textSec, fontWeight: FontWeight.w500, height: 1.4),
          ),
          if (isChunkRecording && currentChunkPath.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Current chunk: $currentChunkPath',
              style: TextStyle(fontSize: 11, color: _T.textMuted, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onOpenRecordings,
            icon: const Icon(Icons.library_music_rounded, size: 15),
            label: const Text('View Recordings'),
            style: TextButton.styleFrom(
              foregroundColor: _T.info,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }
}

// Animated pulsing dot for live recording
class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 7, height: 7,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(const Color(0xFF16A34A), const Color(0xFF4ADE80), _c.value),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recordings Screen
// ─────────────────────────────────────────────────────────────────────────────
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
  void initState() { super.initState(); _initialize(); }

  @override
  void dispose() { _stopPlayback(); super.dispose(); }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLabel = prefs.getString(_cleanupPreferenceKey);
    if (savedLabel != null && _cleanupOptions.containsKey(savedLabel)) _cleanupLabel = savedLabel;
    await _loadFiles();
  }

  Future<void> _loadFiles() async {
    if (widget.saveDirectory.isEmpty) {
      if (!mounted) return;
      setState(() { _files = const []; _isLoading = false; });
      return;
    }
    final dir = Directory(widget.saveDirectory);
    if (!await dir.exists()) {
      if (!mounted) return;
      setState(() { _files = const []; _isLoading = false; });
      return;
    }
    await _runAutoCleanup(dir);
    final entities = await dir.list().where((e) => e.path.endsWith('.m4a')).toList();
    entities.sort((a, b) => File(b.path).lastModifiedSync().compareTo(File(a.path).lastModifiedSync()));
    if (!mounted) return;
    setState(() {
      _files = entities;
      _selectedPaths.removeWhere((path) => !_files.any((f) => f.path == path));
      if (_selectedPaths.isEmpty) _selectionMode = false;
      _isLoading = false;
    });
  }

  Future<void> _runAutoCleanup(Directory dir) async {
    final retentionSeconds = _cleanupOptions[_cleanupLabel];
    if (retentionSeconds == null) return;
    final cutoff = DateTime.now().subtract(Duration(seconds: retentionSeconds));
    final entities = await dir.list().where((e) => e.path.endsWith('.m4a')).toList();
    for (final entity in entities) {
      final file = File(entity.path);
      final modifiedAt = await file.lastModified();
      if (modifiedAt.isBefore(cutoff)) await file.delete();
    }
  }

  Future<void> _togglePlayback(String path) async {
    if (_playingPath == path) {
      await _stopPlayback();
      if (!mounted) return;
      setState(() => _playingPath = null);
      return;
    }
    final started = await _audioChunkChannel.invokeMethod<bool>('playChunkAudio', <String, dynamic>{'path': path}) ?? false;
    if (!mounted) return;
    if (started) setState(() => _playingPath = path);
    else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not play this recording.'), behavior: SnackBarBehavior.floating));
  }

  Future<void> _stopPlayback() async {
    try { await _audioChunkChannel.invokeMethod<bool>('stopChunkAudio'); } catch (_) {}
  }

  Future<void> _deleteFile(String path) async {
    if (_playingPath == path) {
      await _stopPlayback();
      if (mounted) setState(() => _playingPath = null);
    }
    final file = File(path);
    if (await file.exists()) await file.delete();
    await _loadFiles();
  }

  Future<void> _toggleSelection(String path) async {
    setState(() {
      _selectionMode = true;
      if (_selectedPaths.contains(path)) _selectedPaths.remove(path);
      else _selectedPaths.add(path);
      if (_selectedPaths.isEmpty) _selectionMode = false;
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
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.redPrimary),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ?? false;
    if (!shouldDelete) return;
    await _stopPlayback();
    for (final path in _selectedPaths.toList()) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (!mounted) return;
    setState(() { _playingPath = null; _selectedPaths.clear(); _selectionMode = false; });
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
    return Scaffold(
      backgroundColor: _T.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _selectionMode ? '${_selectedPaths.length} selected' : 'Recorded Chunks',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: _T.textPrimary, letterSpacing: -0.3),
        ),
        actions: [
          if (_selectionMode)
            IconButton(onPressed: _deleteSelected, icon: const Icon(Icons.delete_rounded, color: AppColors.redPrimary)),
          if (_selectionMode)
            IconButton(
              onPressed: () => setState(() { _selectionMode = false; _selectedPaths.clear(); }),
              icon: const Icon(Icons.close_rounded),
            ),
          IconButton(onPressed: _loadFiles, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _files.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(color: _T.roseTint, shape: BoxShape.circle),
                        child: const Icon(Icons.mic_off_rounded, color: _T.roseMid, size: 30),
                      ),
                      const SizedBox(height: 14),
                      const Text('No recordings yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _T.textPrimary)),
                      const SizedBox(height: 6),
                      Text('Start a recording from the home screen', style: TextStyle(fontSize: 13, color: _T.textSec)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _files.length + 1,
                  separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 14 : 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _T.cardBorder),
                          boxShadow: [BoxShadow(color: _T.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.auto_delete_rounded, size: 16, color: _T.textSec),
                            const SizedBox(width: 10),
                            const Expanded(child: Text('Auto cleanup', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _T.textPrimary))),
                            DropdownButton<String>(
                              value: _cleanupLabel,
                              underline: const SizedBox.shrink(),
                              style: const TextStyle(fontSize: 13, color: _T.textPrimary, fontWeight: FontWeight.w600),
                              items: _cleanupOptions.keys
                                  .map((label) => DropdownMenuItem<String>(value: label, child: Text(label)))
                                  .toList(growable: false),
                              onChanged: (next) { if (next == null) return; _updateCleanupPreference(next); },
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
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? const Color(0xFF93C5FD) : _T.cardBorder),
                        boxShadow: [BoxShadow(color: _T.cardShadow, blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: ListTile(
                        onTap: () => _selectionMode ? _toggleSelection(file.path) : _togglePlayback(file.path),
                        onLongPress: () => _toggleSelection(file.path),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: _selectionMode
                            ? Checkbox(value: isSelected, onChanged: (_) => _toggleSelection(file.path))
                            : GestureDetector(
                                onTap: () => _togglePlayback(file.path),
                                child: Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: isPlaying ? _T.info.withAlpha(20) : _T.pageBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                                    color: _T.info,
                                    size: 24,
                                  ),
                                ),
                              ),
                        title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _T.textPrimary)),
                        subtitle: Text(
                          '${_formatBytes(stat.size)} · ${stat.modified}',
                          style: TextStyle(fontSize: 11, color: _T.textSec),
                        ),
                        trailing: _selectionMode
                            ? null
                            : IconButton(
                                onPressed: () => _deleteFile(file.path),
                                icon: Icon(Icons.delete_outline_rounded, color: AppColors.redPrimary.withAlpha(190)),
                              ),
                      ),
                    );
                  },
                ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Safety Tip Card
// ─────────────────────────────────────────────────────────────────────────────
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
        duration: const Duration(milliseconds: 320),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: Container(
          key: ValueKey(_i),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, _T.rosePale],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _T.cardBorder),
            boxShadow: [
              BoxShadow(color: _T.roseMid.withAlpha(14), blurRadius: 16, offset: const Offset(0, 6)),
              const BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      gradient: _T.roseGrad,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [BoxShadow(color: _T.roseMid.withAlpha(60), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Icon(icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _T.textPrimary, letterSpacing: -0.3)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: _T.roseTint, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      '${_i + 1}/${_kTips.length}',
                      style: const TextStyle(fontSize: 11, color: _T.roseMid, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(body, style: const TextStyle(fontSize: 13, color: _T.textSec, height: 1.6)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.touch_app_rounded, size: 12, color: _T.textMuted),
                  const SizedBox(width: 5),
                  Text('Tap for next tip', style: TextStyle(fontSize: 11, color: _T.textMuted)),
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
// Shimmer
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
      AnimationController(vsync: this, duration: const Duration(milliseconds: 950))..repeat(reverse: true);

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.lerp(const Color(0xFFEED9E8), const Color(0xFFF9F0F5), _c.value)!,
              Color.lerp(const Color(0xFFF9F0F5), const Color(0xFFEED9E8), _c.value)!,
            ],
          ),
          borderRadius: BorderRadius.circular(widget.height / 2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder tab
// ─────────────────────────────────────────────────────────────────────────────
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
              width: 64, height: 64,
              decoration: BoxDecoration(gradient: _T.roseGrad, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _T.roseMid.withAlpha(60), blurRadius: 16, offset: const Offset(0, 6))]),
              child: Icon(icon, color: Colors.white, size: 30),
            ),
            const SizedBox(height: 14),
            Text(label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _T.textPrimary, letterSpacing: -0.3)),
            const SizedBox(height: 6),
            Text('Coming soon', style: TextStyle(fontSize: 13, color: _T.textSec)),
          ],
        ),
      ),
    );
  }
}