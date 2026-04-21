import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/services/sos_service.dart';
import '../../../core/theme/app_colors.dart';

class AuthorityDashboardScreen extends StatefulWidget {
  const AuthorityDashboardScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AuthorityDashboardScreen> createState() => _AuthorityDashboardScreenState();
}

class _AuthorityDashboardScreenState extends State<AuthorityDashboardScreen> {
  static const Duration _pollInterval = Duration(seconds: 10);

  final SosService _sosService = SosService.instance;

  List<AuthorityAlert> _alerts = const <AuthorityAlert>[];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String _selectedFilter = 'all';
  String? _error;
  DateTime? _lastUpdated;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _loadAlerts(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAlerts({bool silent = false}) async {
    if (!mounted) {
      return;
    }

    if (!silent) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    } else {
      setState(() {
        _isRefreshing = true;
      });
    }

    final int previousActiveCount = _alerts.where((AuthorityAlert alert) => alert.status != 'resolved').length;

    try {
      final List<dynamic> rawAlerts = await _sosService.getActiveSosAlerts();
      final List<AuthorityAlert> parsedAlerts = rawAlerts
          .whereType<Map<String, dynamic>>()
          .map(AuthorityAlert.fromJson)
          .toList()
        ..sort((AuthorityAlert a, AuthorityAlert b) => b.timestamp.compareTo(a.timestamp));

      final int newActiveCount = parsedAlerts.where((AuthorityAlert alert) => alert.status != 'resolved').length;

      if (!mounted) {
        return;
      }

      setState(() {
        _alerts = parsedAlerts;
        _isLoading = false;
        _isRefreshing = false;
        _error = null;
        _lastUpdated = DateTime.now();
      });

      if (silent && newActiveCount > previousActiveCount) {
        final int incomingCount = newActiveCount - previousActiveCount;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(incomingCount == 1
                ? '1 new SOS alert received'
                : '$incomingCount new SOS alerts received'),
            backgroundColor: AppColors.redPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
        _error = e.toString();
      });
    }
  }

  List<AuthorityAlert> get _filteredAlerts {
    if (_selectedFilter == 'all') {
      return _alerts;
    }
    return _alerts.where((AuthorityAlert alert) => alert.status == _selectedFilter).toList();
  }

  Future<void> _openAlertDetails(AuthorityAlert alert) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return _AlertDetailsSheet(
          alert: alert,
          sosService: _sosService,
          onStatusChanged: (String updatedStatus) {
            setState(() {
              _alerts = _alerts
                  .map(
                    (AuthorityAlert existing) => existing.sosId == alert.sosId
                        ? existing.copyWith(status: AuthorityAlert.normalizeStatus(updatedStatus))
                        : existing,
                  )
                  .toList();
            });
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<AuthorityAlert> alerts = _filteredAlerts;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.bluePrimary,
        foregroundColor: Colors.white,
        title: const Text('Authority Command Center'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh alerts',
            onPressed: () => _loadAlerts(),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Logout',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _DashboardHeader(
            alerts: _alerts,
            selectedFilter: _selectedFilter,
            onFilterChanged: (String value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            lastUpdated: _lastUpdated,
            isRefreshing: _isRefreshing,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(
                        error: _error!,
                        onRetry: _loadAlerts,
                      )
                    : RefreshIndicator(
                        color: AppColors.bluePrimary,
                        onRefresh: _loadAlerts,
                        child: alerts.isEmpty
                            ? const _EmptyState()
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
                                itemCount: alerts.length,
                                itemBuilder: (BuildContext context, int index) {
                                  final AuthorityAlert alert = alerts[index];
                                  return _AlertCard(
                                    alert: alert,
                                    onTap: () => _openAlertDetails(alert),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class AuthorityAlert {
  const AuthorityAlert({
    required this.sosId,
    required this.status,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.userDisplay,
    required this.priority,
    required this.audioChunks,
  });

  final String sosId;
  final String status;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String? address;
  final String userDisplay;
  final String priority;
  final int audioChunks;

  factory AuthorityAlert.fromJson(Map<String, dynamic> json) {
    final dynamic locationData = json['location'];
    final dynamic userData = json['user'];
    double latitude = 0;
    double longitude = 0;
    String? address;
    String userDisplay = 'Unknown User';
    int chunkCount = 0;

    if (locationData is Map<String, dynamic>) {
      latitude = _asDouble(locationData['latitude']);
      longitude = _asDouble(locationData['longitude']);
      address = locationData['address'] as String?;
    } else {
      latitude = _asDouble(json['latitude']);
      longitude = _asDouble(json['longitude']);
    }

    if (userData is Map<String, dynamic>) {
      userDisplay = (userData['full_name'] ?? userData['name'] ?? userData['phone_number'] ?? userData['email'] ?? 'Unknown User').toString();
      address ??= userData['address_line'] as String?;
    } else {
      userDisplay = (json['victim_name'] ?? json['user_name'] ?? json['user_email'] ?? 'Unknown User').toString();
    }

    final dynamic chunks = json['audio_chunks'];
    if (chunks is List<dynamic>) {
      chunkCount = chunks.length;
    } else {
      chunkCount = (json['audio_chunks_count'] as int?) ?? (json['audioChunksCount'] as int?) ?? 0;
    }

    final String status = normalizeStatus((json['status'] as String? ?? 'triggered').toLowerCase());

    return AuthorityAlert(
      sosId: (json['sos_id'] ?? json['id'] ?? 'unknown').toString(),
      status: status,
      timestamp: DateTime.tryParse((json['created_at'] ?? json['triggered_at'] ?? json['timestamp'] ?? '').toString()) ?? DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      address: json['address'] as String? ?? address,
      userDisplay: userDisplay,
      priority: (json['priority'] ?? _priorityFromStatus(status)).toString().toUpperCase(),
      audioChunks: chunkCount,
    );
  }

  AuthorityAlert copyWith({
    String? sosId,
    String? status,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? address,
    String? userDisplay,
    String? priority,
    int? audioChunks,
  }) {
    return AuthorityAlert(
      sosId: sosId ?? this.sosId,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      userDisplay: userDisplay ?? this.userDisplay,
      priority: priority ?? this.priority,
      audioChunks: audioChunks ?? this.audioChunks,
    );
  }

  static String normalizeStatus(String rawStatus) {
    switch (rawStatus.trim().toLowerCase()) {
      case 'active':
      case 'open':
      case 'triggered':
        return 'triggered';
      case 'assigned':
      case 'in-progress':
      case 'in_progress':
        return 'in_progress';
      case 'closed':
      case 'resolved':
        return 'resolved';
      case 'false_alarm':
      case 'false-alarm':
        return 'false_alarm';
      default:
        return rawStatus.trim().toLowerCase();
    }
  }

  static String _priorityFromStatus(String status) {
    switch (status) {
      case 'triggered':
        return 'HIGH';
      case 'in_progress':
        return 'MEDIUM';
      case 'resolved':
        return 'LOW';
      default:
        return 'MEDIUM';
    }
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.alerts,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.lastUpdated,
    required this.isRefreshing,
  });

  final List<AuthorityAlert> alerts;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;
  final DateTime? lastUpdated;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final int activeCount = alerts.where((AuthorityAlert alert) => alert.status == 'triggered').length;
    final int progressCount = alerts.where((AuthorityAlert alert) => alert.status == 'in_progress').length;
    final int resolvedCount = alerts.where((AuthorityAlert alert) => alert.status == 'resolved').length;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.bluePrimary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Live Incident Feed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: isRefreshing ? 1 : 0,
                  child: const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              lastUpdated == null
                  ? 'Waiting for first sync...'
                  : 'Synced ${_relativeTime(lastUpdated!)}',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MiniMetricCard(
                    color: AppColors.redPrimary,
                    label: 'Triggered',
                    value: activeCount.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniMetricCard(
                    color: AppColors.amberPrimary,
                    label: 'In Progress',
                    value: progressCount.toString(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniMetricCard(
                    color: AppColors.greenPrimary,
                    label: 'Resolved',
                    value: resolvedCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: <Widget>[
                  _FilterChip(
                    label: 'All',
                    value: 'all',
                    selectedValue: selectedFilter,
                    onSelected: onFilterChanged,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Triggered',
                    value: 'triggered',
                    selectedValue: selectedFilter,
                    onSelected: onFilterChanged,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'In Progress',
                    value: 'in_progress',
                    selectedValue: selectedFilter,
                    onSelected: onFilterChanged,
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Resolved',
                    value: 'resolved',
                    selectedValue: selectedFilter,
                    onSelected: onFilterChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime lastUpdated) {
    final Duration delta = DateTime.now().difference(lastUpdated);
    if (delta.inSeconds < 10) {
      return 'just now';
    }
    if (delta.inMinutes < 1) {
      return '${delta.inSeconds}s ago';
    }
    if (delta.inHours < 1) {
      return '${delta.inMinutes}m ago';
    }
    return '${delta.inHours}h ago';
  }
}

class _MiniMetricCard extends StatelessWidget {
  const _MiniMetricCard({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD7E0F2),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
  });

  final String label;
  final String value;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final bool selected = value == selectedValue;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? Colors.white : Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.bluePrimary : Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onTap});

  final AuthorityAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color stateColor = _statusColor(alert.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.sos, color: stateColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            alert.userDisplay,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'SOS #${alert.sosId}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(status: alert.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    const Icon(Icons.place_outlined, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        alert.address ?? '${alert.latitude.toStringAsFixed(5)}, ${alert.longitude.toStringAsFixed(5)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    const Icon(Icons.schedule, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimestamp(alert.timestamp),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${alert.audioChunks} audio chunks',
                        style: const TextStyle(
                          color: AppColors.bluePrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'triggered':
        return AppColors.redPrimary;
      case 'in_progress':
        return AppColors.amberPrimary;
      case 'resolved':
        return AppColors.greenPrimary;
      default:
        return AppColors.bluePrimary;
    }
  }

  static String _formatTimestamp(DateTime time) {
    final DateTime local = time.toLocal();
    final String hour = local.hour.toString().padLeft(2, '0');
    final String minute = local.minute.toString().padLeft(2, '0');
    final String day = local.day.toString().padLeft(2, '0');
    final String month = local.month.toString().padLeft(2, '0');
    return '$day/$month • $hour:$minute';
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final String label;

    switch (status) {
      case 'triggered':
        color = AppColors.redPrimary;
        label = 'Triggered';
        break;
      case 'in_progress':
        color = AppColors.amberPrimary;
        label = 'In Progress';
        break;
      case 'resolved':
        color = AppColors.greenPrimary;
        label = 'Resolved';
        break;
      default:
        color = AppColors.bluePrimary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AlertDetailsSheet extends StatefulWidget {
  const _AlertDetailsSheet({
    required this.alert,
    required this.sosService,
    required this.onStatusChanged,
  });

  final AuthorityAlert alert;
  final SosService sosService;
  final ValueChanged<String> onStatusChanged;

  @override
  State<_AlertDetailsSheet> createState() => _AlertDetailsSheetState();
}

class _AlertDetailsSheetState extends State<_AlertDetailsSheet> {
  static const Duration _detailsPollInterval = Duration(seconds: 6);

  bool _isLoadingDetails = true;
  bool _isSubmittingStatus = false;
  String _currentStatus = 'triggered';
  String? _phone;
  String? _address;
  String? _latestNote;
  int _audioChunks = 0;
  String? _error;
  List<_SosAudioChunk> _audioChunkItems = const <_SosAudioChunk>[];
  String? _playingChunkUrl;

  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _detailsPollTimer;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<void>? _playerCompleteSub;

  PlayerState _playerState = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.alert.status;
    _address = widget.alert.address;
    _audioChunks = widget.alert.audioChunks;
    _loadDetails();
    _detailsPollTimer = Timer.periodic(_detailsPollInterval, (_) {
      _loadDetails(silent: true);
    });

    _playerStateSub = _audioPlayer.onPlayerStateChanged.listen((PlayerState state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playerState = state;
      });
    });

    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _playingChunkUrl = null;
        _playerState = PlayerState.stopped;
      });
    });
  }

  @override
  void dispose() {
    _detailsPollTimer?.cancel();
    _playerStateSub?.cancel();
    _playerCompleteSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadDetails({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _isLoadingDetails = true;
        _error = null;
      });
    }

    try {
      final Map<String, dynamic> details = await widget.sosService.getSosDetails(widget.alert.sosId);
      if (!mounted) {
        return;
      }

      final dynamic userData = details['user'];
      final dynamic locationData = details['location'];
      final dynamic audioData = details['audio_chunks'];
      final List<_SosAudioChunk> parsedChunks = _parseAudioChunks(audioData);

      setState(() {
        _currentStatus = AuthorityAlert.normalizeStatus((details['status'] ?? widget.alert.status).toString());
        if (userData is Map<String, dynamic>) {
          _phone = userData['phone_number']?.toString();
          _address = _address ?? userData['address_line']?.toString();
        }
        if (locationData is Map<String, dynamic>) {
          _address = locationData['address']?.toString() ?? _address;
        }
        _audioChunkItems = parsedChunks;
        _audioChunks = parsedChunks.length;
        _latestNote = details['latest_note']?.toString();
        _isLoadingDetails = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoadingDetails = false;
        _error = e.toString();
      });
    }
  }

  List<_SosAudioChunk> _parseAudioChunks(dynamic audioData) {
    if (audioData is! List<dynamic>) {
      return const <_SosAudioChunk>[];
    }

    final List<_SosAudioChunk> parsed = audioData
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> chunk) {
          final String? url = (chunk['audio_url'] ?? chunk['url'])?.toString();
          if (url == null || url.isEmpty) {
            return null;
          }
          final int index = (chunk['chunk_index'] as num?)?.toInt() ?? 0;
          final DateTime? uploadedAt = DateTime.tryParse((chunk['uploaded_at'] ?? '').toString());
          return _SosAudioChunk(
            index: index,
            url: url,
            uploadedAt: uploadedAt,
          );
        })
        .whereType<_SosAudioChunk>()
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return parsed;
  }

  Future<void> _toggleChunkPlayback(_SosAudioChunk chunk) async {
    try {
      if (_playingChunkUrl == chunk.url) {
        if (_playerState == PlayerState.playing) {
          await _audioPlayer.pause();
          return;
        }
        if (_playerState == PlayerState.paused) {
          await _audioPlayer.resume();
          return;
        }
      }

      await _audioPlayer.stop();
      await _audioPlayer.play(UrlSource(chunk.url));

      if (!mounted) {
        return;
      }
      setState(() {
        _playingChunkUrl = chunk.url;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to play audio chunk: $e')),
      );
    }
  }

  Future<void> _updateStatus(String status, String successMessage) async {
    setState(() {
      _isSubmittingStatus = true;
    });

    try {
      final Map<String, dynamic> result = await widget.sosService.updateSosStatus(
        widget.alert.sosId,
        status: status,
      );

      if (!mounted) {
        return;
      }

      final String updatedStatus = AuthorityAlert.normalizeStatus((result['status'] ?? status).toString());
      widget.onStatusChanged(updatedStatus);

      setState(() {
        _isSubmittingStatus = false;
        _currentStatus = updatedStatus;
      });

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmittingStatus = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String visibleAddress = _address ?? '${widget.alert.latitude.toStringAsFixed(5)}, ${widget.alert.longitude.toStringAsFixed(5)}';

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          18,
          16,
          18,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.alert.userDisplay,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusPill(status: _currentStatus),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'SOS #${widget.alert.sosId}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            _DetailRow(
              icon: Icons.place,
              title: 'Coordinates',
              value: '${widget.alert.latitude.toStringAsFixed(5)}, ${widget.alert.longitude.toStringAsFixed(5)}',
            ),
            _DetailRow(
              icon: Icons.home,
              title: 'Address',
              value: visibleAddress,
            ),
            _DetailRow(
              icon: Icons.schedule,
              title: 'Triggered At',
              value: _AlertCard._formatTimestamp(widget.alert.timestamp),
            ),
            _DetailRow(
              icon: Icons.mic,
              title: 'Audio Chunks',
              value: _audioChunks.toString(),
            ),
            if (_phone != null)
              _DetailRow(
                icon: Icons.phone,
                title: 'Victim Contact',
                value: _phone!,
              ),
            if (_latestNote != null && _latestNote!.isNotEmpty)
              _DetailRow(
                icon: Icons.notes,
                title: 'Latest Note',
                value: _latestNote!,
              ),
            if (_isLoadingDetails)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.redPrimary, fontSize: 12),
                ),
              ),
            _DetailRow(
              icon: Icons.warning_amber_rounded,
              title: 'Priority',
              value: widget.alert.priority,
            ),
            const SizedBox(height: 10),
            const Text(
              'Live Audio Chunks',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Chunk list refreshes automatically every 6 seconds.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 10),
            if (_audioChunkItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'No uploaded chunks yet. New chunks will appear here as they arrive.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Column(
                children: _audioChunkItems.map((chunk) {
                  final bool isCurrent = _playingChunkUrl == chunk.url;
                  final bool isPlaying = isCurrent && _playerState == PlayerState.playing;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: IconButton(
                          onPressed: () => _toggleChunkPlayback(chunk),
                          icon: Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill),
                          color: AppColors.bluePrimary,
                        ),
                        title: Text(
                          'Chunk #${chunk.index}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          chunk.uploadedAt == null
                              ? 'Upload time unavailable'
                              : 'Uploaded ${_AlertCard._formatTimestamp(chunk.uploadedAt!)}',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                        trailing: isCurrent
                            ? Icon(
                                isPlaying ? Icons.graphic_eq : Icons.pause,
                                color: AppColors.bluePrimary,
                              )
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 18),
            const Text(
              'Suggested Response',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Dispatch nearest patrol unit and attempt callback with victim immediately.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 18),
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSubmittingStatus || _currentStatus == 'in_progress'
                        ? null
                        : () => _updateStatus('in_progress', 'Alert marked as in progress.'),
                    icon: const Icon(Icons.local_police),
                    label: Text(_isSubmittingStatus ? 'Updating...' : 'Assign Unit'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bluePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSubmittingStatus || _currentStatus == 'resolved'
                        ? null
                        : () => _updateStatus('resolved', 'Alert marked as resolved.'),
                    icon: const Icon(Icons.task_alt),
                    label: const Text('Resolve'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.greenPrimary,
                      side: const BorderSide(color: AppColors.greenPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _isSubmittingStatus || _currentStatus == 'false_alarm'
                    ? null
                    : () => _updateStatus('false_alarm', 'Alert marked as false alarm.'),
                icon: const Icon(Icons.report_off),
                label: const Text('Mark As False Alarm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SosAudioChunk {
  const _SosAudioChunk({
    required this.index,
    required this.url,
    required this.uploadedAt,
  });

  final int index;
  final String url;
  final DateTime? uploadedAt;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 18, color: AppColors.bluePrimary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Icon(Icons.wifi_off, size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 10),
            const Text(
              'Unable to fetch live alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const <Widget>[
        SizedBox(height: 90),
        Icon(Icons.verified_user_outlined, size: 56, color: AppColors.greenPrimary),
        SizedBox(height: 10),
        Center(
          child: Text(
            'No active incidents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Incoming SOS alerts will appear here in real time.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}
