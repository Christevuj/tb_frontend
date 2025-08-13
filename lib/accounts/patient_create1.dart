import 'package:flutter/material.dart';
import 'package:tb_frontend/guest/glanding_page.dart';
import 'package:tb_frontend/login_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _hasAgreed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTermsDialog());
  }

  void _showTermsDialog() {
    bool isChecked = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Terms of Use and Privacy Policy Agreement'),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Effective Date: June 11, 2025\n\n'
                      'By accessing or using the TBisita platform, you hereby acknowledge and agree to be bound by the following Terms of Use and Privacy Policy. If you do not agree to these terms, you must discontinue use of the Service.\n\n'
                      'By using TBisita, you expressly consent to the collection, processing, and storage of your personal data, which may include but is not limited to:\n'
                      '• Full name, age, sex, and contact information\n'
                      '• Health-related information (e.g., TB symptoms, medication schedules, treatment adherence)\n'
                      '• Usage data such as check-ins, consultation logs, and communication with health workers\n\n'
                      'This data will be used solely for the purpose of tracking, monitoring, and improving tuberculosis care. Authorized TB-DOTS health workers and licensed medical professionals may access your data to support treatment, provide follow-ups, and ensure medical compliance. Your data will be handled with strict confidentiality in accordance with the Data Privacy Act of 2012 (Republic Act No. 10173) of the Philippines.\n\n'
                      'You agree to:\n'
                      '• Provide true, accurate, and up-to-date information;\n'
                      '• Use the Service in compliance with applicable laws and regulations;\n'
                      '• Keep your login credentials secure and confidential.\n\n'
                      'All content, features, source code, and design elements of TBisita are the exclusive property of the developers and may not be copied, modified, distributed, or used without prior written consent.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text(
                        'I agree to the company Terms of Service and Privacy Policy',
                        style: TextStyle(fontSize: 14),
                      ),
                      value: isChecked,
                      onChanged: (value) {
                        setStateDialog(() {
                          isChecked = value ?? false;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isChecked
                      ? () {
                          setState(() {
                            _hasAgreed = true;
                          });
                          Navigator.of(context).pop();
                        }
                      : null,
                  child: const Text('Continue'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAgreed) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sign up',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _firstNameController,
                decoration: InputDecoration(
                  labelText: 'First name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _lastNameController,
                decoration: InputDecoration(
                  labelText: 'Last name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // Handle Sign Up logic here
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const GlandingPage()),
                    );
                  },
                  child: const Text(
                    'Guest Mode',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
              const Spacer(),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TBisitaLoginScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Log in',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
