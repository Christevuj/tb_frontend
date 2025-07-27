import 'package:flutter/material.dart';
import 'package:tb_frontend/login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // White background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // TBisita Logo
              Image.asset(
                'assets/images/tbisita_logo.png',
                height: 230,
              ),
              const SizedBox(height: 30),

              // Title
              const Text(
                'Monitor your TB treatment with TBisita',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF4C72), // Main pink
                ),
              ),
              const SizedBox(height: 12),

              // Description
              const Text(
                'TBisita is a mobile tool designed to help TB patients stay on track with treatment and connect easily with healthcare providers.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 30),

              // Manual Dots Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildDot(isActive: true),
                  buildDot(isActive: false),
                  buildDot(isActive: false),
                ],
              ),

              const Spacer(),

              // Next Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => TBisitaLoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4C72),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Skip Button
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => TBisitaLoginScreen()),
                  );
                },
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Color(0xFFFF4C72),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Dot builder
  static Widget buildDot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 5),
      height: 8,
      width: isActive ? 20 : 8,
      decoration: BoxDecoration(
        color:
            isActive ? const Color(0xFFFF4C72) : const Color(0xFFFFC0CB), // pink
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}
