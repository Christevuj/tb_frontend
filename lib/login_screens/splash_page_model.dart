import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class TbisitaSplashPage extends StatefulWidget {
  const TbisitaSplashPage({super.key});

  @override
  State<TbisitaSplashPage> createState() => _TbisitaSplashPageState();
}

class _TbisitaSplashPageState extends State<TbisitaSplashPage>
  with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;
  Animation<double>? _logoTranslationAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();

    // Heartbeat-like logo animation (pulse + bob + subtle rotation)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();

    // Scale: quick pulse then settle
    _logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.14).chain(CurveTween(curve: Curves.easeOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.14, end: 0.96).chain(CurveTween(curve: Curves.easeIn)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.96, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_logoController);

    // Rotation: tiny sway in phase with the pulse
    _logoRotationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.04), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: -0.03), weight: 30),
      TweenSequenceItem(tween: Tween(begin: -0.03, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeInOut));

    // Vertical bob: slight lift on pulse then settle
    _logoTranslationAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 6.0), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _logoController.dispose();
    super.dispose();
  }

  void _navigateToOnboarding() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _navigateToOnboarding,
        child: Container(
          color: Colors.white,
          child: Center(
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated Logo with subtle scale/rotation and shadow
                    AnimatedBuilder(
                      animation: _logoController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _logoTranslationAnimation?.value ?? 0.0),
                          child: Transform.rotate(
                            angle: _logoRotationAnimation.value,
                            child: Transform.scale(
                              scale: _logoScaleAnimation.value,
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: Image.asset(
                        'assets/images/tbisita_logo2.png',
                        width: 270,
                        height: 270,
                        fit: BoxFit.contain,
                      ),
                    ),
                    // App name removed per UI update
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
