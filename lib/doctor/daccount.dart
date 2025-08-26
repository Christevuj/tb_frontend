import 'package:flutter/material.dart';
import 'package:tb_frontend/accounts/patient_create1.dart';
import 'package:tb_frontend/login_screen.dart';
import 'package:tb_frontend/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class Daccount extends StatefulWidget {
  const Daccount({super.key});

  @override
  State<Daccount> createState() => _DaccountState();
}

class _DaccountState extends State<Daccount> {
  final AuthService _authService = AuthService();

  String? firstName;
  String? lastName;
  String? email;
  bool isLoading = true;

  // 🔹 Editable values for buttons
  final double buttonFontSize = 15;
  final double buttonPaddingV = 15;
  final double buttonPaddingH = 15;

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

  // Floating field with optional icon
  Widget _buildFloatingField(String label, String value,
      {IconData? icon, VoidCallback? onEdit}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: onEdit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              if (icon != null) Icon(icon, color: Colors.redAccent, size: 22),
              if (icon != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            value,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (onEdit != null)
                          const Icon(Icons.edit,
                              size: 18, color: Colors.redAccent),
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
  }

  // Password field
  Widget _buildPasswordField() {
    return _buildFloatingField("Password", "********", icon: Icons.lock);
  }

  Future<void> _editField(
      String label, String currentValue, Function(String) onSave) async {
    final controller = TextEditingController(text: currentValue);
    final firebase_auth.User? authUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(labelText: label),
          obscureText: label == "Password",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                if (label == "First Name" || label == "Last Name") {
                  Map<String, dynamic> updateData = {};
                  if (label == "First Name") {
                    updateData['firstName'] = controller.text.trim();
                  } else if (label == "Last Name") {
                    updateData['lastName'] = controller.text.trim();
                  }

                  if (updateData.isNotEmpty) {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(authUser.uid)
                        .update(updateData);
                  }
                }

                onSave(controller.text.trim());
                Navigator.pop(context);
              } on firebase_auth.FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.message}')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unexpected error: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _removeAccount() async {
    final firebase_auth.User? authUser =
        firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Account'),
        content: const Text(
            'Are you sure you want to remove your account? This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Remove')),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final email = authUser.email;
      if (email != null) {
        final passwordController = TextEditingController();
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm Password'),
            content: TextField(
              controller: passwordController,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Enter your password'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Confirm'),
              ),
            ],
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
    await firebase_auth.FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const TBisitaLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ Full white background
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // 🔹 Profile picture stays redAccent
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

                  const SizedBox(height: 20),

                  if (isGuest)
                    const Text(
                      "You are currently using a guest account.\nPlease create an account to enjoy full access to features such as saving your appointments, messaging, and more.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.black54),
                    ),

                  if (!isGuest) ...[
                    _buildFloatingField("First Name", firstName ?? "",
                        icon: Icons.person, onEdit: () {
                      _editField("First Name", firstName ?? "", (val) {
                        setState(() {
                          firstName = val;
                        });
                      });
                    }),
                    _buildFloatingField("Last Name", lastName ?? "",
                        icon: Icons.person_outline, onEdit: () {
                      _editField("Last Name", lastName ?? "", (val) {
                        setState(() {
                          lastName = val;
                        });
                      });
                    }),
                    _buildFloatingField("Email", email ?? "",
                        icon: Icons.email),
                    _buildPasswordField(),
                    const SizedBox(height: 20),

                    // 🔹 Remove Account Button (smaller, centered)
                    Center(
                      child: SizedBox(
                        width: 220,
                        child: OutlinedButton(
                          onPressed: _removeAccount,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: Colors.redAccent, width: 2),
                            padding: EdgeInsets.symmetric(
                                vertical: buttonPaddingV,
                                horizontal: buttonPaddingH),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: Text(
                            "Remove Account",
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 🔹 Log Out Button (smaller, centered)
                    Center(
                      child: SizedBox(
                        width: 220,
                        child: ElevatedButton(
                          onPressed: _logout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: EdgeInsets.symmetric(
                                vertical: buttonPaddingV,
                                horizontal: buttonPaddingH),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: Text(
                            "Log Out",
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),

                  if (isGuest)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SignupScreen()),
                        );
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
