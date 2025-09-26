import 'package:flutter/material.dart';
import 'package:tb_frontend/login_screen.dart';
import 'package:tb_frontend/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _hasAgreed = false;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

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
      builder: (context) {
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
                        'I agree to the Terms of Service and Privacy Policy',
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
                          setState(() => _hasAgreed = true);
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

  Future<void> _signUp() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    String? error = await _authService.signUp(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'An error occurred')),
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
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Patient Sign Up',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              _buildTextField(_firstNameController, 'First name'),
              const SizedBox(height: 20),
              _buildTextField(_lastNameController, 'Last name'),
              const SizedBox(height: 20),
              _buildTextField(_emailController, 'Email address', email: true),
              const SizedBox(height: 20),
              _buildTextField(_passwordController, 'Password', password: true),
              const SizedBox(height: 30),
              _buildSignUpButton(),
              const Spacer(),
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool password = false, bool email = false}) {
    return TextField(
      controller: controller,
      obscureText: password && _obscurePassword,
      keyboardType: email ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        suffixIcon: password
            ? IconButton(
                icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('Sign Up',
                style: TextStyle(fontSize: 16, color: Colors.white)),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Already have a patient account? '),
          GestureDetector(
            onTap: () =>
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
              MaterialPageRoute(
                  builder: (context) => const TBisitaLoginScreen()),
              (route) => false,
            ),
            child: const Text('Log in',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
