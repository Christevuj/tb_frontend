import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:tb_frontend/guest/glanding_page.dart'; // adjust path if needed


class TBisitaLoginScreen extends StatefulWidget {
  const TBisitaLoginScreen({super.key});

  @override
  _TBisitaLoginScreenState createState() => _TBisitaLoginScreenState();
}

class _TBisitaLoginScreenState extends State<TBisitaLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Log in',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Email field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Password field
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureText = !_obscureText;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Forgot password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    // TODO: Handle forgot password
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: Color(0xFFFF4C72)),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Login button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Handle login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF4C72),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Log in',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // Guest Mode
Center(
  child: TextButton(
    onPressed: () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const GlandingPage()),
      );
    },
    child: const Text(
      'Guest Mode',
      style: TextStyle(color: Color(0xFFFF4C72)),
    ),
  ),
),



              const Spacer(),

              // Sign up
              Center(
                child: RichText(
                  text: TextSpan(
                    text: 'Don’t have an account? ',
                    style: const TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: 'Sign up',
                        style: const TextStyle(color: Color(0xFFFF4C72)),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // TODO: Navigate to Sign up screen
                          },
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
