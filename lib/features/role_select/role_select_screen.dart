import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../women/women_home_screen.dart';
import '../authority/authority_home_screen.dart';

enum _Role { women, authority }

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _card1Fade;
  late final Animation<Offset> _card1Slide;
  late final Animation<double> _card2Fade;
  late final Animation<Offset> _card2Slide;

  late final AnimationController _selectCtrl;
  late final Animation<double> _selectScale;

  _Role? _selectedRole;
  _Role? _pressedRole;

  @override
  void initState() {
    super.initState();

    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _headerFade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.0, 0.45, curve: Curves.easeIn)));
    _headerSlide =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve: const Interval(0.0, 0.55, curve: Curves.easeOut)));

    _card1Fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.25, 0.65, curve: Curves.easeIn)));
    _card1Slide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve: const Interval(0.25, 0.75, curve: Curves.easeOut)));

    _card2Fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _entryCtrl,
        curve: const Interval(0.45, 0.85, curve: Curves.easeIn)));
    _card2Slide =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _entryCtrl,
                curve: const Interval(0.45, 0.95, curve: Curves.easeOut)));

    _selectCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 240));
    _selectScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.02), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.02, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _selectCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _selectCtrl.dispose();
    super.dispose();
  }

  Future<void> _onRoleTap(_Role role) async {
    if (_selectedRole != null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedRole = role;
      _pressedRole = role;
    });
    await _selectCtrl.forward();
    if (!mounted) return;
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (context, anim, secondaryAnim) => role == _Role.women
          ? const WomenHomeScreen()
          : const AuthorityHomeScreen(),
      transitionsBuilder: (context, anim, secondaryAnim, child) =>
          FadeTransition(opacity: anim, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
    if (!mounted) return;
    setState(() {
      _selectedRole = null;
      _pressedRole = null;
    });
    _selectCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 36),

                // ── Header ───────────────────────────────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: SlideTransition(
                    position: _headerSlide,
                    child: const _Header(),
                  ),
                ),

                const SizedBox(height: 28),

                // ── Women card ───────────────────────────────────────────
                Expanded(
                  child: FadeTransition(
                    opacity: _card1Fade,
                    child: SlideTransition(
                      position: _card1Slide,
                      child: AnimatedBuilder(
                        animation: _selectCtrl,
                        builder: (context, child) => Transform.scale(
                          scale: _pressedRole == _Role.women
                              ? _selectScale.value
                              : 1.0,
                          child: child,
                        ),
                        child: _RoleCard(
                          title: 'I need safety',
                          roleLabel: 'WOMEN',
                          description:
                              'SOS alerts, live location sharing,\ntrusted contacts & safe routes.',
                          icon: FontAwesomeIcons.shieldHalved,
                          accentColor: AppColors.rosePrimary,
                          bgGradient: const [
                            Color(0xFFFDF2F8),
                            Color(0xFFFCE7F3),
                          ],
                          onTap: () => _onRoleTap(_Role.women),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── Authority card ───────────────────────────────────────
                Expanded(
                  child: FadeTransition(
                    opacity: _card2Fade,
                    child: SlideTransition(
                      position: _card2Slide,
                      child: AnimatedBuilder(
                        animation: _selectCtrl,
                        builder: (context, child) => Transform.scale(
                          scale: _pressedRole == _Role.authority
                              ? _selectScale.value
                              : 1.0,
                          child: child,
                        ),
                        child: _RoleCard(
                          title: 'I respond to alerts',
                          roleLabel: 'AUTHORITY',
                          description:
                              'Monitor emergencies, coordinate\nresponse & manage contacts.',
                          icon: FontAwesomeIcons.userShield,
                          accentColor: AppColors.bluePrimary,
                          bgGradient: const [
                            Color(0xFFF0F4FF),
                            Color(0xFFE0EAFF),
                          ],
                          onTap: () => _onRoleTap(_Role.authority),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset('assets/app_logo/purple_logo_no_bg.png',
                width: 26, height: 26),
            const SizedBox(width: 7),
            const Text(
              'haven',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.rosePrimary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'Who are\nyou?',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            height: 1.05,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Select your role to continue.',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ── Role Card ─────────────────────────────────────────────────────────────────
class _RoleCard extends StatefulWidget {
  final String title;
  final String roleLabel;
  final String description;
  final FaIconData icon;
  final Color accentColor;
  final List<Color> bgGradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.roleLabel,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.bgGradient,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _borderAnim;
  late final Animation<double> _iconAnim;
  bool _isDown = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 160));
    _borderAnim = Tween<double>(begin: 0.18, end: 1.0)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
    _iconAnim = Tween<double>(begin: 1.0, end: 1.18)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _down(TapDownDetails d) {
    setState(() => _isDown = true);
    _pressCtrl.forward();
  }

  void _up(TapUpDetails d) {
    setState(() => _isDown = false);
    _pressCtrl.reverse();
  }

  void _cancel() {
    setState(() => _isDown = false);
    _pressCtrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _pressCtrl,
        builder: (context, child) {
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.bgGradient,
              ),
              border: Border.all(
                color:
                    widget.accentColor.withValues(alpha: _borderAnim.value),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor
                      .withValues(alpha: _isDown ? 0.22 : 0.08),
                  blurRadius: _isDown ? 28 : 16,
                  spreadRadius: _isDown ? 2 : 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // ── Top: icon + pill ──────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.scale(
                        scale: _iconAnim.value,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color:
                                  widget.accentColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: FaIcon(widget.icon,
                                color: widget.accentColor, size: 24),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: widget.accentColor.withValues(alpha: 0.22),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          widget.roleLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: widget.accentColor,
                            letterSpacing: 1.8,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Bottom: text + CTA ────────────────────────────────
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.description,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textSecondary,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.accentColor,
                            ),
                          ),
                          const SizedBox(width: 5),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            transform: Matrix4.translationValues(
                                _isDown ? 6 : 0, 0, 0),
                            child: FaIcon(FontAwesomeIcons.arrowRight,
                                color: widget.accentColor, size: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
