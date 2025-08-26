import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 Patient Sign Up (self-registration)
  Future<String?> signUpPatient({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    try {
      // Create user in Firebase Auth
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Save patient details to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'role': 'patient', // default role for self-signup
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // ✅ Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        return 'Password must be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email address.';
      }
      return 'Authentication error: ${e.message}';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  // 🔹 Convenience wrapper for SignupScreen
  Future<String?> signUp({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
  }) async {
    return await signUpPatient(
      firstName: firstName,
      lastName: lastName,
      email: email,
      password: password,
    );
  }

  // 🔹 Admin creates other accounts (doctor, healthworker, etc.)
  Future<String?> createUserByAdmin({
    required String email,
    required String password,
    required String role, // doctor | healthworker | admin
    required String name, // full name for staff users
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Save staff details to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'name': name.trim(),
        'email': email.trim(),
        'role': role.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; // ✅ Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        return 'This email is already registered.';
      } else if (e.code == 'weak-password') {
        return 'Password must be at least 6 characters.';
      } else if (e.code == 'invalid-email') {
        return 'Invalid email address.';
      }
      return 'Authentication error: ${e.message}';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  // 🔹 Login user
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return null; // ✅ Success
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        return 'No account found with this email.';
      } else if (e.code == 'wrong-password') {
        return 'Incorrect password.';
      }
      return 'Login error: ${e.message}';
    } catch (e) {
      return 'Unexpected error: $e';
    }
  }

  // 🔹 Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 🔹 Current logged-in user
  User? get currentUser => _auth.currentUser;

  // 🔹 Get current user details
  Future<Map<String, dynamic>?> getCurrentUserDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // 🔹 Convenience getters
  Future<String?> getCurrentUserFirstName() async {
    final details = await getCurrentUserDetails();
    return details?['firstName']; // Only exists for patients
  }

  Future<String?> getCurrentUserLastName() async {
    final details = await getCurrentUserDetails();
    return details?['lastName']; // Only exists for patients
  }

  Future<String?> getCurrentUserName() async {
    final details = await getCurrentUserDetails();
    return details?['name']; // Only exists for doctors/admins/healthworkers
  }

  Future<String?> getCurrentUserRole() async {
    final details = await getCurrentUserDetails();
    return details?['role'];
  }

  Future<String?> getCurrentUserEmail() async {
    final details = await getCurrentUserDetails();
    return details?['email'];
  }
}
