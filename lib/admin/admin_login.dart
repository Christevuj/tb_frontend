import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tb_frontend/services/auth_service.dart'; // Import your AuthService
import 'package:tb_frontend/login_screen.dart'; // Import login screen
import 'admin_dashboard.dart'; // Import your admin dashboard page

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  final String welcomeText = "Welcome Back, Master 🙇🏻";
  late List<bool> _visibleLetters;
  int _currentLetterIndex = 0;
  Timer? _timer;
  late List<String> _characters;

  // Checkbox state
  bool _rememberMe = false;

  // Text field controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Auth service
  final AuthService _authService = AuthService();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _characters = welcomeText.characters.toList();
    _visibleLetters = List<bool>.filled(_characters.length, false);

    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    _timer = Timer.periodic(const Duration(milliseconds: 60), (timer) {
      if (_currentLetterIndex < _visibleLetters.length) {
        setState(() {
          _visibleLetters[_currentLetterIndex] = true;
          _currentLetterIndex++;
        });
      } else {
        _timer?.cancel();
      }
    });

    // Load saved credentials
    _loadSavedCredentials();
  }

  // Load saved credentials from SharedPreferences
  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('admin_email');
    final savedPassword = prefs.getString('admin_password');
    final rememberMe = prefs.getBool('admin_remember_me') ?? false;

    if (rememberMe && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  // Save credentials to SharedPreferences
  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    if (_rememberMe) {
      await prefs.setString('admin_email', _emailController.text.trim());
      await prefs.setString('admin_password', _passwordController.text.trim());
      await prefs.setBool('admin_remember_me', true);
    } else {
      await prefs.remove('admin_email');
      await prefs.remove('admin_password');
      await prefs.setBool('admin_remember_me', false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🔹 Admin login method - checks admins collection
  Future<void> _loginAdmin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter email and password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // First, try to sign in with Firebase Auth
      final authError =
          await _authService.signIn(email: email, password: password);

      if (authError != null) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(authError)),
        );
        return;
      }

      // Check if the user exists in the admins collection
      final adminQuery = await FirebaseFirestore.instance
          .collection('admins')
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'admin')
          .get();

      setState(() => _isLoading = false);

      if (adminQuery.docs.isNotEmpty) {
        // Save credentials if remember me is checked
        await _saveCredentials();

        // User is a valid admin, navigate to dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      } else {
        // User is not in admins collection, deny access
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Access denied: You are not authorized as an admin'),
            backgroundColor: Colors.red,
          ),
        );
        // Sign out the user since they're not an admin
        await _authService.signOut();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TBisitaLoginScreen(),
                        ),
                      );
                    },
                    tooltip: 'Back to Login',
                    color: const Color.fromRGBO(255, 82, 82, 1),
                  ),
                ),
                Image.asset(
                  "assets/images/tbisita_logo2.png",
                  height: 80,
                ),
                const SizedBox(height: 20),

                // Animated welcome text
                SlideTransition(
                  position: _slideAnimation,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(_characters.length, (index) {
                      return AnimatedOpacity(
                        opacity: _visibleLetters[index] ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _characters[index],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 8),

                const Text(
                  "Log in to continue",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 25),

                // Email & Password fields
                TextField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: "Email address",
                    prefixIcon: const Icon(Icons.email),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Remember Me checkbox
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      activeColor: const Color.fromRGBO(255, 82, 82, 1),
                    ),
                    const Text("Remember Me"),
                  ],
                ),
                const SizedBox(height: 20),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(255, 82, 82, 1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _loginAdmin,
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            "Log In",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    "Forgot Password?",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
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
