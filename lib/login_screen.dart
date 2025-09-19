import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tb_frontend/guest/gmenu.dart';
import 'package:tb_frontend/accounts/patient_create1.dart';
import 'package:flutter/foundation.dart';
import 'package:tb_frontend/admin/admin_login.dart';
import 'package:tb_frontend/patient/pmenu.dart'; // ✅ Patient wrapper
import 'package:tb_frontend/doctor/dmenu.dart'; // ✅ Doctor wrapper
import 'package:tb_frontend/healthcare/hmenu.dart'; // ✅ Health Worker wrapper

class TBisitaLoginScreen extends StatelessWidget {
  const TBisitaLoginScreen({super.key});

  OutlineInputBorder _border(bool isError) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: isError ? Colors.red : Colors.grey,
        width: 1.5,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final obscureText = ValueNotifier<bool>(true);
    final isLoading = ValueNotifier<bool>(false);
    final emailError = ValueNotifier<bool>(false);
    final passwordError = ValueNotifier<bool>(false);

    final FirebaseAuth auth = FirebaseAuth.instance;

    int adminTapCount = 0;

    Future<void> loginUser() async {
      emailError.value = false;
      passwordError.value = false;

      if (emailController.text.trim().isEmpty ||
          passwordController.text.trim().isEmpty) {
        emailError.value = emailController.text.trim().isEmpty;
        passwordError.value = passwordController.text.trim().isEmpty;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter email and password')),
        );
        return;
      }

      isLoading.value = true;

      try {
        final userCredential = await auth.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        final uid = userCredential.user!.uid;

        // Try to get user role from multiple collections
        try {
          // First try users collection
          var userDoc = await FirebaseFirestore.instance
              .collection("users")
              .doc(uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data()!;
            final role = data['role'] ?? 'patient';

            // Navigate based on role
            Widget homePage;
            if (role == 'patient') {
              homePage = const PatientMainWrapper(initialIndex: 0);
            } else if (role == 'doctor') {
              homePage = const DoctorMainWrapper(initialIndex: 0);
            } else if (role == 'admin') {
              homePage = const AdminLogin();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Unknown role")),
              );
              return;
            }

            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => homePage),
              (route) => false,
            );
            return;
          }

          // Then try doctors collection
          var doctorDoc = await FirebaseFirestore.instance
              .collection("doctors")
              .doc(uid)
              .get();

          if (doctorDoc.exists) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const DoctorMainWrapper(initialIndex: 0)),
              (route) => false,
            );
            return;
          }

          // Finally try healthcare workers
          var healthcareDoc = await FirebaseFirestore.instance
              .collection("healthcare")
              .doc(uid)
              .get();

          if (healthcareDoc.exists) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const HealthMainWrapper(initialIndex: 0)),
              (route) => false,
            );
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            print("Error accessing Firestore: $e");
          }
          // If we get a permission error, let's check if we're authenticated
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            // User is authenticated but we can't access Firestore
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Error: Could not access user data. Please contact support."),
                duration: Duration(seconds: 5),
              ),
            );
          } else {
            // User is not authenticated
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    "Error: Authentication failed. Please try logging in again."),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // If no collection has this UID
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No account found in records.")),
        );
      } on FirebaseAuthException catch (e) {
        emailError.value = true;
        passwordError.value = true;

        String message = 'Please enter valid credentials';
        if (e.code == 'user-not-found') {
          message = 'No user found for that email.';
        } else if (e.code == 'wrong-password') {
          message = 'Wrong password provided.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}")),
        );
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () {
                  adminTapCount++;
                  if (adminTapCount >= 5) {
                    adminTapCount = 0;
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminLogin(),
                      ),
                      (route) => false,
                    );
                  }
                },
                child: const Text(
                  'Log in',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              ValueListenableBuilder<bool>(
                valueListenable: emailError,
                builder: (_, isError, __) => TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    labelStyle:
                        TextStyle(color: isError ? Colors.red : Colors.grey),
                    border: _border(isError),
                    focusedBorder: _border(isError),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ValueListenableBuilder2<bool, bool>(
                first: passwordError,
                second: obscureText,
                builder: (_, isError, isObscure, __) => TextField(
                  controller: passwordController,
                  obscureText: isObscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle:
                        TextStyle(color: isError ? Colors.red : Colors.grey),
                    border: _border(isError),
                    focusedBorder: _border(isError),
                    suffixIcon: IconButton(
                      icon: Icon(
                        isObscure ? Icons.visibility_off : Icons.visibility,
                        color: isError ? Colors.red : Colors.grey,
                      ),
                      onPressed: () => obscureText.value = !isObscure,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: Color(0xFFFF4C72)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<bool>(
                valueListenable: isLoading,
                builder: (_, loading, __) => SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : loginUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                        : const Text(
                            'Log in',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Center(
                child: TextButton(
                  onPressed: () {
                    // Directly navigate to guest mode without logout
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const GuestMainWrapper()),
                      (route) => false,
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
                child: RichText(
                  text: TextSpan(
                    text: 'Don’t have an account? ',
                    style: const TextStyle(color: Colors.black87),
                    children: [
                      TextSpan(
                        text: 'Sign up',
                        style: const TextStyle(color: Colors.redAccent),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SignupScreen(),
                              ),
                            );
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

// Helper for two ValueNotifiers
class ValueListenableBuilder2<A, B> extends StatelessWidget {
  final ValueListenable<A> first;
  final ValueListenable<B> second;
  final Widget Function(BuildContext, A, B, Widget?) builder;

  const ValueListenableBuilder2({
    super.key,
    required this.first,
    required this.second,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<A>(
      valueListenable: first,
      builder: (context, valueA, _) {
        return ValueListenableBuilder<B>(
          valueListenable: second,
          builder: (context, valueB, child) {
            return builder(context, valueA, valueB, child);
          },
        );
      },
    );
  }
}
