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
  // Logo is now static; only page-level animations are used

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

    // No logo animation: keep the page-level _controller for fade/scale only
  }

  @override
  void dispose() {
    _controller.dispose();
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
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 48),
              child: FadeTransition(
                opacity: _opacityAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Static logo (page-level animations still apply)
                      Image.asset(
                        'assets/images/tbisita_logo2.png',
                        width: 270,
                        height: 270,
                        fit: BoxFit.contain,
                      ),
                      // Thin, small slogan directly under the logo (no gap)
                      Text(
                        'Your telemedicine guide for TB care',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
