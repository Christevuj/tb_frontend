import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔹 Sign Up new user
  Future<String?> signUp({
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

      // Save user details to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
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
      if (doc.exists) {
        return {
          'firstName': doc['firstName'] ?? '',
          'lastName': doc['lastName'] ?? '',
          'email': doc['email'] ?? '',
        };
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // 🔹 Get individual user fields
  Future<String?> getCurrentUserFirstName() async {
    final details = await getCurrentUserDetails();
    return details?['firstName'] ?? 'User';
  }

  Future<String?> getCurrentUserLastName() async {
    final details = await getCurrentUserDetails();
    return details?['lastName'] ?? '';
  }

  Future<String?> getCurrentUserEmail() async {
    final details = await getCurrentUserDetails();
    return details?['email'] ?? '';
  }
}
