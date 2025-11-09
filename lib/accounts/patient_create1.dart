import 'package:flutter/material.dart';
import 'package:tb_frontend/login_screen.dart';
import 'package:tb_frontend/services/auth_service.dart';
// import '../data/tb_dots_facilities.dart' show TBDotsFacility, tbDotsFacilities;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

Widget _buildModernBullet(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 10, left: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6),
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.grey.shade700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SignupScreenState extends State<SignupScreen> {
  // TBDotsFacility? _selectedFacility;
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _hasAgreed = false;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  // Password strength validation flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  void _validatePassword(String password) {
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordValid =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showTermsDialog();
    });
  }

  void _showTermsDialog() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        bool isChecked = false;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: 520,
                    maxHeight: MediaQuery.of(context).size.height * 0.75),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header (white background, redAccent theme)
                    // Header (redAccent background, one-line title)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.privacy_tip,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  'Terms of Use & Privacy Policy',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 2),
                                Text('Effective Date: June 11, 2025',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body (white background) with a Scrollbar to ensure content is visible
                    Expanded(
                      child: Container(
                        color: Colors.grey.shade50,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 20),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Introduction Section
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue.shade100),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.info_outline, color: Colors.blue.shade700, size: 22),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'By accessing or using the TBisita platform, you hereby acknowledge and agree to be bound by the following Terms of Use and Privacy Policy. If you do not agree to these terms, you must discontinue use of the Service.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            height: 1.6,
                                            color: Colors.grey.shade800,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Data Collection Section
                                Text(
                                  'Data Collection',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'We collect the following information:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildModernBullet('Full name, age, sex, and contact information'),
                                _buildModernBullet('Health-related information (e.g., TB symptoms, medication schedules, treatment adherence)'),
                                _buildModernBullet('Usage data such as check-ins, consultation logs, and communication with health workers'),
                                const SizedBox(height: 20),
                                
                                // Legal Compliance Section
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.red.shade50, Colors.orange.shade50],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200, width: 1.5),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.verified_user, color: Colors.red.shade700, size: 22),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Legal Compliance',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text.rich(
                                        TextSpan(
                                          text:
                                              'This data will be used solely for the purpose of tracking, monitoring, and improving tuberculosis care. Authorized TB-DOTS health workers and licensed medical professionals may access your data to support treatment, provide follow-ups, and ensure medical compliance.\n\nYour data will be handled with strict confidentiality in accordance with:\n\n',
                                          style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey.shade800),
                                          children: [
                                            TextSpan(
                                                text: '• Data Privacy Act of 2012 (RA 10173)\n',
                                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade900)),
                                            TextSpan(
                                                text: '• Mandatory Reporting of Notifiable Diseases and Health Events of Public Health Concern Act (RA 11332)\n',
                                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade900)),
                                            TextSpan(
                                                text: '• Cybercrime Prevention Act of 2012 (RA 10175)',
                                                style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red.shade900)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // User Agreement Section
                                Text(
                                  'User Agreement',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'By using this service, you agree to:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade700,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _buildModernBullet('Provide true, accurate, and up-to-date information'),
                                _buildModernBullet('Use the Service in compliance with applicable laws and regulations'),
                                _buildModernBullet('Keep your login credentials secure and confidential'),
                                const SizedBox(height: 24),
                                
                                // Intellectual Property Section
                                Text(
                                  'Intellectual Property',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.grey.shade900,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'All content, features, source code, and design elements of TBisita are the exclusive property of the developers and may not be copied, modified, distributed, or used without prior written consent.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.6,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                
                                // Agreement checkbox
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    controlAffinity: ListTileControlAffinity.leading,
                                    title: Text(
                                      'I agree to the Terms of Service and Privacy Policy',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey.shade900,
                                      ),
                                    ),
                                    value: isChecked,
                                    activeColor: Colors.redAccent,
                                    onChanged: (value) {
                                      setStateDialog(() {
                                        isChecked = value ?? false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(24)),
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.white),
                            onPressed: () {
                              // Close dialog and navigate back to login screen
                              Navigator.of(context).pop(false);
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                    builder: (context) =>
                                        const TBisitaLoginScreen()),
                                (route) => false,
                              );
                            },
                            child: const Text('Cancel',
                                style: TextStyle(
                                    fontSize: 15,
                                    color: Color.fromARGB(255, 0, 0, 0))),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: isChecked
                                ? () {
                                    setState(() => _hasAgreed = true);
                                    Navigator.of(context).pop(true);
                                  }
                                : null,
                            icon: isChecked
                                ? const Icon(Icons.arrow_forward,
                                    color: Colors.white)
                                : const SizedBox.shrink(),
                            label: const Text('Continue',
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((accepted) {
      if (accepted == true) setState(() => _hasAgreed = true);
    });
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

    // Validate password strength
    if (!_isPasswordValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please meet all password requirements'),
          backgroundColor: Colors.red,
        ),
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

    if (error == null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(18),
                  child: const Icon(Icons.check_circle_outline,
                      color: Colors.redAccent, size: 48),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Account created successfully!',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'You can now log in with your credentials.',
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (context) => const TBisitaLoginScreen()),
                        (route) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('OK',
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasAgreed) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back Button and Title Row
              Row(
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Color(0xFF1F2937), size: 20),
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                              builder: (context) => const TBisitaLoginScreen()),
                          (route) => false,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Patient Sign Up',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              _buildTextField(_firstNameController, 'First name'),
              const SizedBox(height: 20),
              _buildTextField(_lastNameController, 'Last name'),
              const SizedBox(height: 20),
              _buildTextField(_emailController, 'Email address', email: true),
              const SizedBox(height: 20),
              _buildTextField(_passwordController, 'Password', password: true),
              const SizedBox(height: 12),
              _buildPasswordStrengthIndicator(),
              const SizedBox(height: 20),
              _buildSignUpButton(),
              const SizedBox(height: 40),
              _buildLoginLink(),
              const SizedBox(height: 20),
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
      onChanged: password ? _validatePassword : null,
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

  Widget _buildPasswordStrengthIndicator() {
    if (_passwordController.text.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPasswordValid ? Icons.check_circle : Icons.info_outline,
                color: _isPasswordValid ? Colors.green : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Password Requirements',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRequirement('At least 8 characters', _hasMinLength),
          _buildRequirement('Contains uppercase letter (A-Z)', _hasUppercase),
          _buildRequirement('Contains lowercase letter (a-z)', _hasLowercase),
          _buildRequirement('Contains number (0-9)', _hasNumber),
          _buildRequirement('Contains special character (!@#\$%^&*)', _hasSpecialChar),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.cancel,
            color: isMet ? Colors.green : Colors.red,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isMet ? Colors.green.shade700 : Colors.grey.shade600,
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _showSignupConfirmationDialog(),
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

  Future<void> _showSignupConfirmationDialog() async {
    // Build summary values
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final visiblePassword = _passwordController.text;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final showPassword = ValueNotifier<bool>(true);
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.redAccent.shade200, Colors.redAccent.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.person_add_alt_1, color: Colors.white, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Confirm your details',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Please review the information below before submitting your account.',
                            style: TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),

                          // Summary table
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Table(
                              columnWidths: const {0: FlexColumnWidth(0.4), 1: FlexColumnWidth(0.6)},
                              children: [
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('First name', style: TextStyle(color: Colors.grey.shade700)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(firstName.isEmpty ? '—' : firstName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Last name', style: TextStyle(color: Colors.grey.shade700)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(lastName.isEmpty ? '—' : lastName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Email', style: TextStyle(color: Colors.grey.shade700)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(email.isEmpty ? '—' : email, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                ]),
                                TableRow(children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text('Password', style: TextStyle(color: Colors.grey.shade700)),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: ValueListenableBuilder<bool>(
                                            valueListenable: showPassword,
                                            builder: (context, show, _) {
                                              final passwordDisplay = visiblePassword.isEmpty
                                                  ? '—'
                                                  : (show
                                                      ? visiblePassword
                                                      : List.filled(visiblePassword.length, '*').join());
                                              return Text(
                                                passwordDisplay,
                                                style: const TextStyle(letterSpacing: 1.2),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        InkWell(
                                          onTap: () => showPassword.value = !showPassword.value,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Padding(
                                            padding: const EdgeInsets.all(6),
                                            child: ValueListenableBuilder<bool>(
                                              valueListenable: showPassword,
                                              builder: (context, show, _) => Icon(
                                                show ? Icons.visibility : Icons.visibility_off,
                                                size: 20,
                                                color: Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Buttons
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.black87)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pop(true);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: const Text('Submit', style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true) {
      // Proceed with actual sign up
      await _signUp();
    }
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
