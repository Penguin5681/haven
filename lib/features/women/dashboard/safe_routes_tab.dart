import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────────────────

class SafePlace {
  const SafePlace({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String address;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get coordinateLabel => hasCoordinates
      ? '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}'
      : 'Address only';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt.toIso8601String(),
      };

  factory SafePlace.fromJson(Map<String, dynamic> json) => SafePlace(
        id: (json['id'] ?? '').toString(),
        name: (json['name'] ?? 'Safe Place').toString(),
        address: (json['address'] ?? 'Pinned location').toString(),
        latitude: _toDoubleOrNull(json['latitude']),
        longitude: _toDoubleOrNull(json['longitude']),
        createdAt:
            DateTime.tryParse((json['created_at'] ?? '').toString()) ??
                DateTime.now(),
      );

  static double? _toDoubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();
    final String text = (value ?? '').toString().trim();
    return text.isEmpty ? null : double.tryParse(text);
  }
}

// ─────────────────────────────────────────────────────────
// Main tab widget
// ─────────────────────────────────────────────────────────

class SafeRoutesTab extends StatefulWidget {
  const SafeRoutesTab({super.key});

  @override
  State<SafeRoutesTab> createState() => _SafeRoutesTabState();
}

class _SafeRoutesTabState extends State<SafeRoutesTab> {
  List<SafePlace> _safePlaces = <SafePlace>[];
  bool _isLoading = true;

  // ── Lifecycle ────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadSafePlaces();
  }

  // ── Persistence ──────────────────────────────────────────

  Future<void> _loadSafePlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? routesJson = prefs.getString('safe_routes_list');
      if (routesJson != null && routesJson.isNotEmpty) {
        final List<dynamic> decoded =
            jsonDecode(routesJson) as List<dynamic>;
        _safePlaces = decoded
            .whereType<Map<String, dynamic>>()
            .map(SafePlace.fromJson)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
    } catch (_) {
      // If stored data is corrupt, start fresh.
      _safePlaces = <SafePlace>[];
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _saveSafePlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'safe_routes_list',
        jsonEncode(_safePlaces.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Persist failure is non-fatal; the in-memory list remains correct.
    }
  }

  Future<void> _addSafePlace({
    required String name,
    required String address,
    required double? latitude,
    required double? longitude,
  }) async {
    final SafePlace newPlace = SafePlace(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
    );
    setState(() => _safePlaces = <SafePlace>[newPlace, ..._safePlaces]);
    await _saveSafePlaces();
  }

  Future<void> _deleteSafePlace(String id) async {
    setState(() => _safePlaces.removeWhere((p) => p.id == id));
    await _saveSafePlaces();
  }

  // ── Actions ──────────────────────────────────────────────

  Future<void> _startNavigation(SafePlace place) async {
    // BUG FIX: build the full URI correctly via Uri() instead of string
    // interpolation so that address strings are always properly encoded.
    final Uri navUri;
    if (place.hasCoordinates) {
      navUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${place.latitude},${place.longitude}'
        '&travelmode=driving',
      );
    } else {
      navUri = Uri(
        scheme: 'https',
        host: 'www.google.com',
        path: '/maps/dir/',
        queryParameters: <String, String>{
          'api': '1',
          'destination': place.address,
          'travelmode': 'driving',
        },
      );
    }

    try {
      await launchUrl(navUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<bool> _ensureLocationAccess() async {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please turn on device location services.')),
        );
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Location permission is required for current position.')),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _confirmDelete(SafePlace place) async {
    final bool shouldDelete = await showDialog<bool>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Remove safe place?'),
            content: Text('Delete "${place.name}" from your saved places?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.redPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete || !mounted) return;

    await _deleteSafePlace(place.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${place.name}" removed.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Add-place bottom sheet ────────────────────────────────

  Future<void> _openAddSafePlaceSheet() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    // BUG FIX: capture messenger before the async gap so we never use
    // `context` after an await.
    final ScaffoldMessengerState messenger =
        ScaffoldMessenger.of(context);

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext sheetContext) {
          return _AddSafePlaceSheet(
            nameController: nameController,
            addressController: addressController,
            messenger: messenger,
            onUseCurrentLocation: () async {
              final bool allowed = await _ensureLocationAccess();
              return allowed
                  ? await _fetchCurrentLatLng(messenger)
                  : null;
            },
            onSave: (
              String name,
              String address,
              latlng.LatLng? point,
            ) async {
              await _addSafePlace(
                name: name,
                address: address,
                latitude: point?.latitude,
                longitude: point?.longitude,
              );
              // BUG FIX: use sheetContext (the modal route's context) for pop.
              if (sheetContext.mounted) {
                Navigator.of(sheetContext).pop();
              }
            },
          );
        },
      );
    } finally {
      // BUG FIX: always dispose controllers even if the sheet threw.
      nameController.dispose();
      addressController.dispose();
    }
  }

  Future<latlng.LatLng?> _fetchCurrentLatLng(
      ScaffoldMessengerState messenger) async {
    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return latlng.LatLng(position.latitude, position.longitude);
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unable to fetch current location.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F7),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: <Widget>[
                _buildAppBar(),
                if (_safePlaces.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else ...<Widget>[
                  SliverToBoxAdapter(child: _buildHintBanner()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList.separated(
                      itemCount: _safePlaces.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, int i) =>
                          _SafePlaceCard(
                        place: _safePlaces[i],
                        onNavigate: () => _startNavigation(_safePlaces[i]),
                        onDelete: () => _confirmDelete(_safePlaces[i]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
      floatingActionButton: _buildFab(),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x14000000),
      elevation: 1,
      title: const Text(
        'Safe Routes',
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
      ),
    );
  }

  Widget _buildHintBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFDF2F8), Color(0xFFFFF7ED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE8F3)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.touch_app_rounded,
                size: 18, color: AppColors.rosePrimary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tap any card to launch navigation instantly.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[Color(0xFFFFF7ED), Color(0xFFFDE8F3)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x18B45309),
                  blurRadius: 20,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.map_outlined,
                size: 46, color: Color(0xFFB45309)),
          ),
          const SizedBox(height: 22),
          const Text(
            'No safe places saved yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pin your trusted places — home, a friend\'s house, a police station — and reach them in one tap.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: _openAddSafePlaceSheet,
            icon: const Icon(Icons.add_location_alt_rounded),
            label: const Text('Add Your First Safe Place'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rosePrimary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFab() {
    if (_safePlaces.isEmpty) return null;
    return FloatingActionButton.extended(
      onPressed: _openAddSafePlaceSheet,
      icon: const Icon(Icons.add_location_alt_rounded),
      label: const Text('Add Safe Place'),
      backgroundColor: AppColors.rosePrimary,
      foregroundColor: Colors.white,
      elevation: 3,
    );
  }
}

// ─────────────────────────────────────────────────────────
// Safe place card
// ─────────────────────────────────────────────────────────

class _SafePlaceCard extends StatelessWidget {
  const _SafePlaceCard({
    required this.place,
    required this.onNavigate,
    required this.onDelete,
  });

  final SafePlace place;
  final VoidCallback onNavigate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      shadowColor: const Color(0x0F000000),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onNavigate,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Icon badge
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.place_rounded,
                    color: Color(0xFFB45309), size: 22),
              ),
              const SizedBox(width: 13),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      place.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      place.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.route_rounded,
                              size: 12, color: AppColors.bluePrimary),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              place.coordinateLabel,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.bluePrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _ActionButton(
                    icon: Icons.navigation_rounded,
                    color: AppColors.greenPrimary,
                    bgColor: const Color(0xFFECFDF5),
                    tooltip: 'Navigate',
                    onTap: onNavigate,
                  ),
                  const SizedBox(height: 6),
                  _ActionButton(
                    icon: Icons.delete_outline_rounded,
                    color: AppColors.redPrimary,
                    bgColor: const Color(0xFFFFF1F2),
                    tooltip: 'Delete',
                    onTap: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Add-place bottom sheet (extracted widget so it manages
// its own state without depending on the parent's context
// across async boundaries).
// ─────────────────────────────────────────────────────────

class _AddSafePlaceSheet extends StatefulWidget {
  const _AddSafePlaceSheet({
    required this.nameController,
    required this.addressController,
    required this.messenger,
    required this.onUseCurrentLocation,
    required this.onSave,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final ScaffoldMessengerState messenger;
  final Future<latlng.LatLng?> Function() onUseCurrentLocation;
  final Future<void> Function(String name, String address, latlng.LatLng? point)
      onSave;

  @override
  State<_AddSafePlaceSheet> createState() => _AddSafePlaceSheetState();
}

class _AddSafePlaceSheetState extends State<_AddSafePlaceSheet> {
  latlng.LatLng? _selectedPoint;
  bool _saving = false;
  bool _fetchingLocation = false;

  Future<void> _pickOnMap() async {
    final latlng.LatLng? picked =
        await Navigator.of(context).push<latlng.LatLng>(
      MaterialPageRoute<latlng.LatLng>(
        builder: (_) =>
            _SafePlaceMapPicker(initialPoint: _selectedPoint),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedPoint = picked);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _fetchingLocation = true);
    final latlng.LatLng? point = await widget.onUseCurrentLocation();
    if (!mounted) return;
    setState(() {
      _fetchingLocation = false;
      if (point != null) _selectedPoint = point;
    });
  }

  Future<void> _save() async {
    final String name = widget.nameController.text.trim();
    final String typedAddress = widget.addressController.text.trim();

    if (name.isEmpty) {
      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('Enter a name for this safe place.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedPoint == null && typedAddress.isEmpty) {
      widget.messenger.showSnackBar(
        const SnackBar(
          content: Text('Pick a location on the map or provide an address.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Safe: either typedAddress is non-empty OR _selectedPoint is non-null.
    final String address = typedAddress.isNotEmpty
        ? typedAddress
        : 'Pinned location '
            '(${_selectedPoint!.latitude.toStringAsFixed(4)}, '
            '${_selectedPoint!.longitude.toStringAsFixed(4)})';

    setState(() => _saving = true);
    await widget.onSave(name, address, _selectedPoint);
    // The sheet is popped by onSave; no state update needed after this.
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.viewPaddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const Text(
              'Add Safe Place',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pin a trusted spot and navigate there in one tap.',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            // Name field
            TextField(
              controller: widget.nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _inputDecoration(
                label: 'Name',
                hint: 'Home, Police Station, Friend\'s House…',
                icon: Icons.label_outline_rounded,
              ),
            ),
            const SizedBox(height: 12),
            // Address field
            TextField(
              controller: widget.addressController,
              maxLines: 2,
              decoration: _inputDecoration(
                label: 'Address (optional if pinned)',
                hint: 'Street / area details',
                icon: Icons.location_on_outlined,
              ),
            ),
            const SizedBox(height: 14),
            // Selected point display
            if (_selectedPoint != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.push_pin_rounded,
                        size: 15, color: AppColors.bluePrimary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pinned: ${_selectedPoint!.latitude.toStringAsFixed(5)}, '
                        '${_selectedPoint!.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: AppColors.bluePrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _selectedPoint = null),
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.bluePrimary),
                    ),
                  ],
                ),
              ),
            // Map / location buttons
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickOnMap,
                    icon: const Icon(Icons.map_outlined, size: 18),
                    label: Text(_selectedPoint == null
                        ? 'Pick on Map'
                        : 'Change Pin'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        _fetchingLocation ? null : _useCurrentLocation,
                    icon: _fetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : const Icon(Icons.my_location_rounded,
                            size: 18),
                    label: const Text('Use Current'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.bluePrimary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rosePrimary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Save Safe Place',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
            BorderSide(color: AppColors.rosePrimary, width: 1.5),
      ),
      filled: true,
      fillColor: const Color(0xFFFAFAFC),
    );
  }
}

// ─────────────────────────────────────────────────────────
// Map picker screen
// ─────────────────────────────────────────────────────────

class _SafePlaceMapPicker extends StatefulWidget {
  const _SafePlaceMapPicker({required this.initialPoint});

  final latlng.LatLng? initialPoint;

  @override
  State<_SafePlaceMapPicker> createState() => _SafePlaceMapPickerState();
}

class _SafePlaceMapPickerState extends State<_SafePlaceMapPicker> {
  // Default center: New Delhi.
  static const latlng.LatLng _defaultCenter = latlng.LatLng(28.6139, 77.2090);

  final MapController _mapController = MapController();
  latlng.LatLng _initialCenter = _defaultCenter;
  latlng.LatLng? _selectedPoint;
  bool _loadingLocation = true;

  // BUG FIX: track whether the map widget is ready to receive controller
  // commands. We use onMapReady to set this flag.
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    _selectedPoint = widget.initialPoint;
    if (_selectedPoint != null) {
      _initialCenter = _selectedPoint!;
      _loadingLocation = false;
    } else {
      _resolveInitialCenter();
    }
  }

  // BUG FIX: dispose the MapController to prevent memory leaks.
  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _resolveInitialCenter() async {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _loadingLocation = false);
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _loadingLocation = false);
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final latlng.LatLng point =
          latlng.LatLng(position.latitude, position.longitude);
      setState(() {
        _initialCenter = point;
        _loadingLocation = false;
      });
      // BUG FIX: only call move() once the map controller is ready.
      if (_mapReady) {
        _mapController.move(point, 14);
      }
      // If not ready yet, onMapReady will call move() instead.
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _moveToCurrentLocation() async {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please turn on device location services.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission denied.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final latlng.LatLng point =
          latlng.LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedPoint = point;
      });
      _mapController.move(point, 15);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to get current location.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4F7),
      appBar: AppBar(
        title: const Text(
          'Pick Location',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        shadowColor: const Color(0x14000000),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: _selectedPoint == null
                  ? null
                  : () => Navigator.of(context).pop(_selectedPoint),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.rosePrimary,
                disabledForegroundColor: AppColors.textSecondary,
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          // Status bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: _selectedPoint != null
                  ? const Color(0xFFEFF6FF)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedPoint != null
                    ? const Color(0xFFBFDBFE)
                    : const Color(0xFFF0E0EA),
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  _selectedPoint != null
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                  size: 16,
                  color: _selectedPoint != null
                      ? AppColors.bluePrimary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedPoint == null
                        ? 'Tap anywhere on the map to drop a pin.'
                        : 'Pinned: '
                            '${_selectedPoint!.latitude.toStringAsFixed(5)}, '
                            '${_selectedPoint!.longitude.toStringAsFixed(5)}',
                    style: TextStyle(
                      color: _selectedPoint != null
                          ? AppColors.bluePrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Map
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _initialCenter,
                    initialZoom: 13,
                    // BUG FIX: set _mapReady flag before moving camera so that
                    // _resolveInitialCenter can safely call move() afterwards.
                    onMapReady: () {
                      _mapReady = true;
                      if (!_loadingLocation &&
                          _selectedPoint == null) {
                        _mapController.move(_initialCenter, 14);
                      }
                    },
                    onTap: (_, latlng.LatLng point) {
                      setState(() => _selectedPoint = point);
                    },
                  ),
                  children: <Widget>[
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.jais.haven',
                    ),
                    if (_selectedPoint != null)
                      MarkerLayer(
                        markers: <Marker>[
                          Marker(
                            point: _selectedPoint!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.redPrimary,
                              size: 42,
                              shadows: <Shadow>[
                                Shadow(
                                  color: Color(0x33000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_loadingLocation)
            const LinearProgressIndicator(minHeight: 2),
          const SizedBox(height: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moveToCurrentLocation,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.bluePrimary,
        elevation: 3,
        tooltip: 'Go to my location',
        child: const Icon(Icons.my_location_rounded),
      ),
    );
  }
}