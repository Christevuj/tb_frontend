import 'package:flutter/material.dart';
import 'package:tb_frontend/accounts/patient_create1.dart';
import 'package:tb_frontend/login_screen.dart';
import 'package:tb_frontend/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
// import 'package:tb_frontend/debug_firestore.dart';

class Paccount extends StatefulWidget {
  const Paccount({super.key});

  @override
  State<Paccount> createState() => _PaccountState();
}

class _PaccountState extends State<Paccount> {
  final AuthService _authService = AuthService();

  String? firstName;
  String? lastName;
  String? email;
  bool isLoading = true;

  // Section expansion
  final Set<String> expandedSections = {};

  @override
  void initState() {
    super.initState();
    _loadUserDetails();
  }

  Future<void> _loadUserDetails() async {
    final details = await _authService.getCurrentUserDetails();
    if (mounted) {
      setState(() {
        firstName = details?['firstName'];
        lastName = details?['lastName'];
        email = details?['email'];
        isLoading = false;
      });
    }
  }

  bool get isGuest => firstName == null || lastName == null || email == null;

  void _toggleSection(String sectionId) {
    setState(() {
      if (expandedSections.contains(sectionId)) {
        expandedSections.remove(sectionId);
      } else {
        expandedSections.add(sectionId);
      }
    });
  }

  Future<void> _editField(
      String label, String currentValue, Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    final newPasswordController = TextEditingController();
    bool newPasswordVisible = true; // Changed to true - visible by default
    
    // Password strength validation flags
    bool hasMinLength = false;
    bool hasUppercase = false;
    bool hasLowercase = false;
    bool hasNumber = false;
    bool hasSpecialChar = false;
    
    final firebase_auth.User? authUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    if (label == "Password") {
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              // Validate password
              void validatePassword(String password) {
                setState(() {
                  hasMinLength = password.length >= 8;
                  hasUppercase = password.contains(RegExp(r'[A-Z]'));
                  hasLowercase = password.contains(RegExp(r'[a-z]'));
                  hasNumber = password.contains(RegExp(r'[0-9]'));
                  hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                });
              }
              
              bool isPasswordValid = hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSpecialChar;
              
              Widget buildRequirement(String text, bool isMet) {
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
              
              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.8,
                  ),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.lock, color: Colors.redAccent, size: 28),
                            const SizedBox(width: 10),
                            const Text(
                              'Edit Password',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: controller,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            labelStyle: const TextStyle(color: Colors.redAccent),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2),
                            ),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: newPasswordController,
                          onChanged: validatePassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            labelStyle: const TextStyle(color: Colors.redAccent),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 1.2),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Colors.redAccent, width: 2),
                            ),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                            suffixIcon: IconButton(
                              icon: Icon(
                                newPasswordVisible
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                color: Colors.redAccent,
                              ),
                              onPressed: () {
                                setState(() {
                                  newPasswordVisible = !newPasswordVisible;
                                });
                              },
                            ),
                          ),
                          obscureText: !newPasswordVisible,
                        ),
                        const SizedBox(height: 12),
                        
                        // Password strength indicator
                        if (newPasswordController.text.isNotEmpty)
                          Container(
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
                                      isPasswordValid ? Icons.check_circle : Icons.info_outline,
                                      color: isPasswordValid ? Colors.green : Colors.orange,
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
                                buildRequirement('At least 8 characters', hasMinLength),
                                buildRequirement('Contains uppercase letter (A-Z)', hasUppercase),
                                buildRequirement('Contains lowercase letter (a-z)', hasLowercase),
                                buildRequirement('Contains number (0-9)', hasNumber),
                                buildRequirement('Contains special character (!@#\$%^&*)', hasSpecialChar),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 10),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPasswordValid ? Colors.redAccent : Colors.grey,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: !isPasswordValid ? null : () async {
                                final newPassword = newPasswordController.text.trim();
                                
                                // Show confirmation dialog
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  barrierColor: Colors.black.withOpacity(0.5),
                                  builder: (dialogContext) {
                                    final showPassword = ValueNotifier<bool>(true); // Changed to true - visible by default
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
                                                  Icon(Icons.security, color: Colors.white, size: 22),
                                                  SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      'Confirm Password Change',
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
                                                    'Are you sure you want to update your password?',
                                                    style: TextStyle(fontSize: 14, color: Colors.black87),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  
                                                  // Password preview
                                                  Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                      color: Colors.grey.shade50,
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.grey.shade200),
                                                    ),
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text('New Password', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                                                        const SizedBox(height: 8),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child: ValueListenableBuilder<bool>(
                                                                valueListenable: showPassword,
                                                                builder: (context, show, _) {
                                                                  final passwordDisplay = show
                                                                      ? newPassword
                                                                      : List.filled(newPassword.length, '•').join();
                                                                  return Text(
                                                                    passwordDisplay,
                                                                    style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w600),
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
                                                      ],
                                                    ),
                                                  ),
                                                  
                                                  const SizedBox(height: 16),
                                                  
                                                  // Buttons
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: OutlinedButton(
                                                          onPressed: () => Navigator.of(dialogContext).pop(false),
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
                                                            Navigator.of(dialogContext).pop(true);
                                                          },
                                                          style: ElevatedButton.styleFrom(
                                                            backgroundColor: Colors.redAccent,
                                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                          ),
                                                          child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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
                                
                                if (confirmed == true) {
                                  try {
                                    await authUser.updatePassword(newPassword);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Password updated successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    onSave(newPassword);
                                  } on firebase_auth.FirebaseAuthException catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: ${e.message}')),
                                    );
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Unexpected error: $e')),
                                    );
                                  }
                                }
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      return;
    }
    // ...existing code...
  }

  Future<void> _removeAccount() async {
    final firebase_auth.User? authUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) => Dialog(
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
                    Icon(Icons.delete_forever, color: Colors.white, size: 22),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Remove Account',
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
                      'Are you sure you want to remove your account? This action cannot be undone.',
                      style: TextStyle(fontSize: 14, color: Colors.black87),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(false),
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
                            onPressed: () => Navigator.of(dialogContext).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Remove', style: TextStyle(color: Colors.white)),
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
      ),
    );

    if (confirm != true) return;

    try {
      final email = authUser.email;
      if (email != null) {
        final passwordController = TextEditingController();
        final shouldProceed = await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.5),
          builder: (dialogContext) => Dialog(
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
                        Icon(Icons.lock, color: Colors.white, size: 22),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Confirm Password',
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
                          'Please enter your password to confirm account removal.',
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Enter your password',
                            labelStyle: const TextStyle(color: Colors.redAccent),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                            ),
                            fillColor: Colors.grey.shade50,
                            filled: true,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
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
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Confirm', style: TextStyle(color: Colors.white)),
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
          ),
        );

        if (shouldProceed != true) return;

        final credential = firebase_auth.EmailAuthProvider.credential(
          email: email,
          password: passwordController.text.trim(),
        );

        await authUser.reauthenticateWithCredential(credential);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(authUser.uid)
          .delete();
      await authUser.delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account successfully removed.')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const TBisitaLoginScreen()),
          (route) => false,
        );
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
  }

  Future<void> _logout() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (dialogContext) {
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
                      Icon(Icons.logout, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Confirm Logout',
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
                        'Are you sure you want to log out of your account?',
                        style: TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      
                      // Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
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
                                Navigator.of(dialogContext).pop(true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Logout', style: TextStyle(color: Colors.white)),
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
    
    if (confirmed == true) {
      await firebase_auth.FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const TBisitaLoginScreen()),
          (route) => false,
        );
      }
    }
  }

  // 🔹 Section Card
  Widget _buildSection({
    required String title,
    required String description,
    required IconData icon,
    required String sectionId,
    required List<Widget> children,
  }) {
    final isExpanded = expandedSections.contains(sectionId);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.redAccent.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ExpansionTile(
        initiallyExpanded: isExpanded,
        onExpansionChanged: (_) => _toggleSection(sectionId),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              alignment: Alignment.center,
              height: 48,
              child: Icon(icon, color: Colors.redAccent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: children,
      ),
    );
  }

  // 🔹 Editable field
  Widget _buildEditableField(String label, String value,
      {IconData? icon, VoidCallback? onEdit, bool obscure = false}) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (icon != null) Icon(icon, color: Colors.redAccent, size: 20),
            if (icon != null) const SizedBox(width: 12),
            Expanded(
              child: Text(
                obscure ? "********" : value,
                style: const TextStyle(fontSize: 15),
              ),
            ),
            if (onEdit != null)
              const Icon(Icons.edit, size: 18, color: Colors.redAccent),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // 🔹 Background gradient + glow
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(255, 255, 255, 255),
                        Color(0xFFFFEBEB)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),

                // 🔹 Content
                SafeArea(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Profile header
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.redAccent,
                          child: isGuest
                              ? const Icon(Icons.person,
                                  size: 60, color: Colors.white)
                              : Text(
                                  firstName!.isNotEmpty
                                      ? firstName![0].toUpperCase()
                                      : "?",
                                  style: const TextStyle(
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 16),
                        if (!isGuest)
                          Text(
                            "$firstName $lastName",
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        if (!isGuest)
                          Text(email ?? "",
                              style: const TextStyle(color: Colors.black54)),
                        if (isGuest)
                          const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Text(
                              "You are currently using a guest account.\nPlease sign up to unlock full features.",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14),
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Sections
                        if (!isGuest) ...[
                          _buildSection(
                            title: "Personal Details",
                            description:
                                "Manage your basic information and profile settings",
                            icon: Icons.person,
                            sectionId: "personal",
                            children: [
                              _buildEditableField("First Name", firstName ?? "",
                                  icon: Icons.person, onEdit: () {
                                _editField("First Name", firstName ?? "",
                                    (val) {
                                  setState(() => firstName = val);
                                });
                              }),
                              _buildEditableField("Last Name", lastName ?? "",
                                  icon: Icons.person_outline, onEdit: () {
                                _editField("Last Name", lastName ?? "", (val) {
                                  setState(() => lastName = val);
                                });
                              }),
                              _buildEditableField("Email", email ?? "",
                                  icon: Icons.email),
                            ],
                          ),
                          
                          _buildSection(
                            title: "Security & Privacy",
                            description:
                                "Manage your password and account security settings",
                            icon: Icons.lock,
                            sectionId: "security",
                            children: [
                              _buildEditableField("Password", "********",
                                  icon: Icons.lock, obscure: true, onEdit: () {
                                _editField("Password", "********", (_) {});
                              }),
                              // (Removed static account status block as requested)
                            ],
                          ),
                          _buildSection(
                            title: "Account Action",
                            description:
                                "Manage your account preferences and data",
                            icon: Icons.settings,
                            sectionId: "actions",
                            children: [
                              // Log Out button moved outside this section
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 24),
                                  side: const BorderSide(
                                      color: Colors.redAccent, width: 2),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30)),
                                ),
                                onPressed: _removeAccount,
                                child: const Text("Remove Account",
                                    style: TextStyle(color: Colors.redAccent)),
                              ),
                            ],
                          ),
                        ],

                        if (!isGuest) ...[
                          const SizedBox(height: 24),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14, horizontal: 24),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: _logout,
                            child: const Text("Log Out",
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],

                        if (isGuest)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 30, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const SignupScreen()),
                              );
                            },
                            child: const Text("Sign Up",
                                style: TextStyle(color: Colors.white)),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
