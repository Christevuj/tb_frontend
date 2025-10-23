import 'package:flutter/material.dart';
import 'onboarding_screen.dart';

class TbisitaSplashPage extends StatefulWidget {
  const TbisitaSplashPage({super.key});

  @override
  State<TbisitaSplashPage> createState() => _TbisitaSplashPageState();
}

class _TbisitaSplashPageState extends State<TbisitaSplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late AnimationController _logoController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoRotationAnimation;

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

    // Independent, subtle repeating animation for the logo
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _logoScaleAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );

    _logoRotationAnimation = Tween<double>(begin: -0.03, end: 0.03).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
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
                        return Transform.rotate(
                          angle: _logoRotationAnimation.value,
                          child: Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          // Make it circular and add layered shadows for depth
                          borderRadius: BorderRadius.circular(120),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(120),
                          child: Image.asset(
                            'assets/images/tbisita_logo2.png',
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
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
