import 'package:flutter/material.dart';
import 'package:tb_frontend/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> onboardingData = [
    {
      "image": "assets/images/splash1.png",
      "title": "Online Consultation",
      "desc":
          "Book appointments with TB specialists and healthcare providers. Get professional medical consultation from the comfort of your home."
    },
    {
      "image": "assets/images/splash2.png",
      "title": "Healthcare Provider Messaging",
      "desc":
          "Connect directly with healthcare providers from different TB treatment facilities. Get quick responses to your questions and concerns."
    },
    {
      "image": "assets/images/splash3.png",
      "title": "AI Medical Assistant",
      "desc":
          "Get instant answers to your TB treatment questions with our AI consultant. Available 24/7 for immediate support when you need it most."
    },
    {
      "image": "assets/images/splash4.png",
      "title": "TB DOTS Facility Locator",
      "desc":
          "Find the nearest TB DOTS treatment facilities in Davao City. Get directions and facility information to continue your treatment journey."
    },
  ];

  void _nextPage() {
    if (_currentPage < onboardingData.length - 1) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finishOnboarding();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _skip() {
    _finishOnboarding();
  }

  void _finishOnboarding() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const TBisitaLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: onboardingData.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) => _buildPage(
                  onboardingData[index]["image"]!,
                  onboardingData[index]["title"]!,
                  onboardingData[index]["desc"]!,
                ),
              ),
            ),

            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                onboardingData.length,
                (index) => _buildDot(isActive: index == _currentPage),
              ),
            ),
            const SizedBox(height: 16),

            // Buttons + Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0)
                  .copyWith(bottom: 30),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (_currentPage > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _previousPage,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.redAccent),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Previous",
                              style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      if (_currentPage > 0) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _currentPage == onboardingData.length - 1
                                ? "Get Started"
                                : "Next",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Skip button placeholder (keeps height consistent)
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40, // fixed height so layout doesn't jump
                    child: (_currentPage < onboardingData.length - 1)
                        ? TextButton(
                            onPressed: _skip,
                            child: const Text(
                              "Skip",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          )
                        : null,
                  ),

                  const SizedBox(height: 15), // extra space below skip
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(String image, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image with rounded corners + shadow + bigger size
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                image,
                height: 300, // bigger image
                fit: BoxFit.cover,
              ),
            ),
          ),

          const SizedBox(height: 25), // reduced gap

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot({required bool isActive}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 20 : 8,
      decoration: BoxDecoration(
        color: isActive ? Colors.redAccent : Colors.redAccent.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
