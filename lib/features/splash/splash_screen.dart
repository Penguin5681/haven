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
  // Panel slides down from off-screen
  late final AnimationController _panelCtrl;
  late final Animation<Offset> _panelSlide;

  // Logo pops in
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;

  // Bottom content rises
  late final AnimationController _bottomCtrl;
  late final Animation<double> _wordOpacity;
  late final Animation<Offset> _wordSlide;
  late final Animation<double> _tagOpacity;

  // Dot loader
  late final AnimationController _dotCtrl;

  // Exit
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
    _panelCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _panelSlide =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
            CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOutCubic));

    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoCtrl,
            curve: const Interval(0.0, 0.4, curve: Curves.easeIn)));

    _bottomCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _wordOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _bottomCtrl,
            curve: const Interval(0.0, 0.6, curve: Curves.easeIn)));
    _wordSlide =
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
            CurvedAnimation(
                parent: _bottomCtrl,
                curve: const Interval(0.0, 0.7, curve: Curves.easeOut)));
    _tagOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _bottomCtrl,
            curve: const Interval(0.4, 1.0, curve: Curves.easeIn)));

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();

    _exitCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _exitOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _exitCtrl, curve: Curves.easeIn));
  }

  Future<void> _run() async {
    await Future.delayed(const Duration(milliseconds: 100));
    _panelCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _bottomCtrl.forward();

    // Check auth while waiting
    final token = await AuthService.instance.getToken();
    final role = await AuthService.instance.getRole();

    // Hold for reading
    await Future.delayed(const Duration(milliseconds: 1600));
    _dotCtrl.stop();
    await _exitCtrl.forward();
    if (!mounted) return;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    Widget next = widget.nextScreen;
    if (token != null && role != null) {
      if (role == 'women') {
        next = const WomenHomeScreen();
      } else if (role == 'authority') {
        next = const AuthorityHomeScreen();
      }
    }

    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (context, anim, secondaryAnim) => next,
      transitionDuration: Duration.zero,
    ));
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    _logoCtrl.dispose();
    _bottomCtrl.dispose();
    _dotCtrl.dispose();
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final topHeight = size.height * 0.58;
    final bottomHeight = size.height * 0.42;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: FadeTransition(
        opacity: _exitOpacity,
        child: Scaffold(
          backgroundColor: AppColors.surface,
          body: Column(
            children: [
              // ── Top brand panel ─────────────────────────────────────────
              SlideTransition(
                position: _panelSlide,
                child: Container(
                  width: double.infinity,
                  height: topHeight,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFBE185D), // roseDeep
                        Color(0xFFDB2777), // rosePrimary
                        Color(0xFFEC4899), // mid rose
                      ],
                      stops: [0.0, 0.55, 1.0],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Decorative circles
                      Positioned(
                        top: -60,
                        right: -40,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        left: -50,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      // Logo centered
                      Center(
                        child: AnimatedBuilder(
                          animation: _logoCtrl,
                          builder: (context, child) => Opacity(
                            opacity: _logoOpacity.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: child,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // White circle backing for the logo
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Image.asset(
                                    'assets/app_logo/purple_logo_no_bg.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom content panel ────────────────────────────────────
              SizedBox(
                height: bottomHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Wordmark
                      FadeTransition(
                        opacity: _wordOpacity,
                        child: SlideTransition(
                          position: _wordSlide,
                          child: const Text(
                            'Safora',
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -1.0,
                              height: 1,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Tagline
                      FadeTransition(
                        opacity: _tagOpacity,
                        child: const Text(
                          'Your safety. Always.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Dot loader
                      AnimatedBuilder(
                        animation: _dotCtrl,
                        builder: (context, child) =>
                            _DotLoader(progress: _dotCtrl.value),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dot loader ────────────────────────────────────────────────────────────────
class _DotLoader extends StatelessWidget {
  final double progress;
  const _DotLoader({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        // Each dot peaks at a different phase
        final phase = i / 3.0;
        final t = ((progress - phase + 1.0) % 1.0);
        // Sine wave: 0 → 1 → 0 over the cycle
        final scale = 0.5 + 0.5 * math.sin(t * math.pi);
        final opacity = 0.3 + 0.7 * math.sin(t * math.pi);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale.clamp(0.4, 1.0),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.rosePrimary,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
