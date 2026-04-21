import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/auth_service.dart';
import '../women/women_home_screen.dart';
import '../authority/authority_home_screen.dart';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({super.key, required this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Slow-drifting aurora orbs in the background
  late final AnimationController _auroraCtrl;

  // Logo pop-in
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoGlow; // drives ring opacity after logo lands

  // Expanding pulse rings
  late final AnimationController _pulseCtrl;

  // Text reveal (name + separator line + tagline)
  late final AnimationController _textCtrl;
  late final Animation<double> _nameOpacity;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _lineScale;
  late final Animation<double> _tagOpacity;

  // Spinning arc loader
  late final AnimationController _loaderCtrl;

  // Full-screen fade-out
  late final AnimationController _exitCtrl;
  late final Animation<double> _exitOpacity;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _build();
    _run();
  }

  void _build() {
    // ── Aurora (continuous slow drift) ──────────────────────────────────────
    _auroraCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 9))
          ..repeat();

    // ── Logo ─────────────────────────────────────────────────────────────────
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoCtrl,
            curve: const Interval(0.0, 0.45, curve: Curves.easeIn)));
    _logoGlow = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoCtrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));

    // ── Pulse rings (continuous) ─────────────────────────────────────────────
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat();

    // ── Text ─────────────────────────────────────────────────────────────────
    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _nameOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut)));
    _nameSlide =
        Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _textCtrl,
                curve: const Interval(0.0, 0.6, curve: Curves.easeOut)));
    _lineScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.3, 0.8, curve: Curves.easeOut)));
    _tagOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _textCtrl,
            curve: const Interval(0.5, 1.0, curve: Curves.easeIn)));

    // ── Arc loader (continuous) ──────────────────────────────────────────────
    _loaderCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();

    // ── Exit ─────────────────────────────────────────────────────────────────
    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeInCubic));
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 180));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 620));
    _textCtrl.forward();

    // Auth check while the screen is visible
    final token = await AuthService.instance.getToken();
    final role = await AuthService.instance.getRole();

    await Future.delayed(const Duration(milliseconds: 1700));
    _loaderCtrl.stop();
    _pulseCtrl.stop();
    await _exitCtrl.forward();
    if (!mounted) return;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    Widget next = widget.nextScreen;
    if (token != null && role != null) {
      if (role == 'women') {
        next = const WomenHomeScreen();
      } else if (role == 'authority') next = const AuthorityHomeScreen();
    }

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => next,
      transitionDuration: Duration.zero,
    ));
  }

  @override
  void dispose() {
    _auroraCtrl.dispose();
    _logoCtrl.dispose();
    _pulseCtrl.dispose();
    _textCtrl.dispose();
    _loaderCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: FadeTransition(
        opacity: _exitOpacity,
        child: Scaffold(
          backgroundColor: AppColors.backgroundDark,
          body: Stack(
            fit: StackFit.expand,
            children: [
              // ── Layer 1: Aurora background ─────────────────────────────────
              AnimatedBuilder(
                animation: _auroraCtrl,
                builder: (_, __) => CustomPaint(
                  size: size,
                  painter: _AuroraPainter(progress: _auroraCtrl.value),
                ),
              ),

              // ── Layer 2: Subtle noise/grain overlay ────────────────────────
              Opacity(
                opacity: 0.04,
                child: Image.asset(
                  'assets/textures/grain.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),

              // ── Layer 3: Main content ──────────────────────────────────────
              SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 3),

                    // Logo + pulse rings
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer pulse rings
                        AnimatedBuilder(
                          animation: _pulseCtrl,
                          builder: (_, __) => _PulseRings(
                            progress: _pulseCtrl.value,
                            masterOpacity: _logoGlow.value,
                          ),
                        ),

                        // Logo medallion
                        AnimatedBuilder(
                          animation: _logoCtrl,
                          builder: (_, child) => Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: child,
                            ),
                          ),
                          child: _LogoMedallion(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 52),

                    // ── Wordmark block ───────────────────────────────────────
                    AnimatedBuilder(
                      animation: _textCtrl,
                      builder: (_, __) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // App name
                          FadeTransition(
                            opacity: _nameOpacity,
                            child: SlideTransition(
                              position: _nameSlide,
                              child: const Text(
                                'SAFORA',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w200,
                                  color: AppColors.textPrimaryDark,
                                  letterSpacing: 14,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Growing gradient separator
                          Transform.scale(
                            scaleX: _lineScale.value,
                            child: Container(
                              width: 160,
                              height: 0.75,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    AppColors.rosePrimary.withValues(alpha: 0.9),
                                    AppColors.roseLight.withValues(alpha: 0.7),
                                    AppColors.rosePrimary.withValues(alpha: 0.9),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // Tagline
                          Opacity(
                            opacity: _tagOpacity.value,
                            child: const Text(
                              'Your safety. Always.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w300,
                                color: AppColors.textSecondaryDark,
                                letterSpacing: 3.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 4),

                    // Arc spinner
                    AnimatedBuilder(
                      animation: _loaderCtrl,
                      builder: (_, __) => _ArcSpinner(progress: _loaderCtrl.value),
                    ),

                    const SizedBox(height: 52),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logo Medallion ────────────────────────────────────────────────────────────
class _LogoMedallion extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 102,
      height: 102,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Rich dark interior
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.3),
          radius: 1.0,
          colors: [
            AppColors.surfaceElevatedDark,
            AppColors.surfaceDark,
          ],
        ),
        // Delicate rose border
        border: Border.all(
          color: AppColors.rosePrimary.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          // Core rose glow
          BoxShadow(
            color: AppColors.rosePrimary.withValues(alpha: 0.45),
            blurRadius: 48,
            spreadRadius: 4,
          ),
          // Soft halo
          BoxShadow(
            color: AppColors.roseLight.withValues(alpha: 0.15),
            blurRadius: 80,
            spreadRadius: 12,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Image.asset(
        'assets/app_logo/purple_logo_no_bg.png',
        fit: BoxFit.contain,
      ),
    );
  }
}

// ── Pulse Rings ───────────────────────────────────────────────────────────────
class _PulseRings extends StatelessWidget {
  final double progress;
  final double masterOpacity;

  const _PulseRings({required this.progress, required this.masterOpacity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(3, (i) {
          final phase = i / 3.0;
          final t = ((progress + phase) % 1.0);
          // Ring expands from 102px to 260px and fades out
          final diameter = 102.0 + t * 158.0;
          final opacity = (1.0 - t) * 0.45 * masterOpacity;
          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.rosePrimary,
                  width: 0.8,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Arc Spinner ───────────────────────────────────────────────────────────────
class _ArcSpinner extends StatelessWidget {
  final double progress;
  const _ArcSpinner({required this.progress});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: CustomPaint(painter: _ArcPainter(progress: progress)),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.5;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = AppColors.rosePrimary.withOpacity(0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Spinning gradient arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweepAngle = math.pi * 1.5;
    final startAngle = progress * math.pi * 2 - math.pi / 2;

    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: [
          Colors.transparent,
          AppColors.roseLight.withOpacity(0.6),
          AppColors.rosePrimary,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);

    // Leading dot
    final dotAngle = startAngle + sweepAngle;
    final dotX = center.dx + radius * math.cos(dotAngle);
    final dotY = center.dy + radius * math.sin(dotAngle);
    canvas.drawCircle(
      Offset(dotX, dotY),
      2.2,
      Paint()..color = AppColors.roseLight,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Aurora Painter ────────────────────────────────────────────────────────────
class _AuroraPainter extends CustomPainter {
  final double progress;
  _AuroraPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final t1 = math.sin(progress * math.pi * 2);
    final t2 = math.cos(progress * math.pi * 2);

    // Orb A — top-left, drifts gently
    _drawOrb(
      canvas,
      center: Offset(
        size.width * 0.12 + t1 * 22,
        size.height * 0.14 + t2 * 14,
      ),
      radius: 260,
      color: const Color(0xFFDB2777),
      opacity: 0.18,
    );

    // Orb B — lower-right, counter-drift
    _drawOrb(
      canvas,
      center: Offset(
        size.width * 0.88 - t2 * 18,
        size.height * 0.78 + t1 * 20,
      ),
      radius: 300,
      color: const Color(0xFF9D174D),
      opacity: 0.16,
    );

    // Orb C — center, large and very faint, tied to logo
    _drawOrb(
      canvas,
      center: Offset(size.width * 0.5, size.height * 0.43),
      radius: 340,
      color: const Color(0xFFEC4899),
      opacity: 0.06,
    );

    // Orb D — mid-left accent
    _drawOrb(
      canvas,
      center: Offset(
        size.width * 0.22 + t2 * 12,
        size.height * 0.65 - t1 * 16,
      ),
      radius: 180,
      color: const Color(0xFFFB7185),
      opacity: 0.09,
    );
  }

  void _drawOrb(Canvas canvas,
      {required Offset center,
      required double radius,
      required Color color,
      required double opacity}) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(opacity), Colors.transparent],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.progress != progress;
}