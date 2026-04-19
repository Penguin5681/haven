import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import 'trusted_contact.dart';
import 'trusted_contacts_store.dart';
import 'trusted_contacts_ui.dart';

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
              onLogout: widget.onLogout,
              trustedContacts: _trustedContacts,
              isLoadingContacts: _isLoadingContacts,
              onAddContact: _addTrustedContact,
              onOpenContacts: _openContactsTab,
            ),
            TrustedContactsTab(
              contacts: _trustedContacts,
              isLoading: _isLoadingContacts,
              onAddContact: _addTrustedContact,
              onDeleteContact: _removeTrustedContact,
            ),
            const _MapTab(),
            const _ProfileTab(),
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

  const _HomeTab({
    required this.onLogout,
    required this.trustedContacts,
    required this.isLoadingContacts,
    required this.onAddContact,
    required this.onOpenContacts,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with TickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  bool _isLoadingProfile = true;

  late final AnimationController _pulse;
  late final AnimationController _hold;
  bool _sosActive = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();

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
    _pulse.dispose();
    _hold.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final data = await AuthService.instance.getProfile();
      if (mounted) setState(() { _profile = data; _isLoadingProfile = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final topPad = MediaQuery.of(context).padding.top;
    final String name = _profile?['full_name'] ?? 'User';
    final String? photoUrl = _profile?['profile_photo_url'];

    return Column(
      children: [
        // ── 1. FIXED HEADER ──────────────────────────────────────────────
        _Header(
          topPad: topPad,
          name: name,
          photoUrl: photoUrl,
          isLoading: _isLoadingProfile,
          onLogout: widget.onLogout,
        ),

        // ── 3. ABOVE-THE-FOLD: SOS HERO ──────────────────────────────────
        //    Critical action. Zero scrolling required.
        SizedBox(
          height: h * 0.38,
          child: _SOSHero(
            pulse: _pulse,
            hold: _hold,
            active: _sosActive,
          ),
        ),

        // ── 4. HIGH-URGENCY SECONDARY ACTIONS ────────────────────────────
        //    Still above-fold, thumb-zone. Share Location & Fake Call.
        _PrimarySecondaryRow(),

        // ── 5. SCROLLABLE TERTIARY CONTENT ───────────────────────────────
        Expanded(
          child: _ScrollZone(
            trustedContacts: widget.trustedContacts,
            isLoadingContacts: widget.isLoadingContacts,
            onAddContact: widget.onAddContact,
            onOpenContacts: widget.onOpenContacts,
          ),
        ),
      ],
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
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _PillAction(
              icon: Icons.phone_in_talk_rounded,
              label: 'Fake Call',
              color: _T.act[1][2],
              bg: _T.act[1][0],
              onTap: () {},
            ),
          ),
        ],
      ),
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

  const _ScrollZone({
    required this.trustedContacts,
    required this.isLoadingContacts,
    required this.onAddContact,
    required this.onOpenContacts,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        const _SectionLabel('More Tools'),
        const SizedBox(height: 12),
        const _TertiaryGrid(),
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
  const _TertiaryGrid();

  static const _items = [
    (Icons.mic_rounded,    'Record Audio', 'Covert background capture', 2),
    (Icons.shield_rounded, 'Safe Places',  'Nearby verified safe zones', 3),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(_items.length, (i) {
        final (icon, title, sub, pi) = _items[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i == 0 ? 0 : 6, right: i == 0 ? 6 : 0),
            child: _TertiaryCard(
              icon: icon,
              title: title,
              sub: sub,
              palette: _T.act[pi],
            ),
          ),
        );
      }),
    );
  }
}

class _TertiaryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final List<Color> palette;
  const _TertiaryCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
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

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) =>
      const _TabPlaceholder(icon: Icons.person_rounded, label: 'My Profile');
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