import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Current user
  User? get currentUser => _auth.currentUser;
  
  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'wrong-password':
          return 'Wrong password';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return 'An error occurred: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Sign up with email and password
  Future<String?> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'The password is too weak';
        case 'email-already-in-use':
          return 'An account already exists for this email';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return 'An error occurred: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Password reset
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          return 'Invalid email address';
        case 'user-not-found':
          return 'No user found with this email';
        default:
          return 'An error occurred: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  // Get auth token
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      print('Get token error: $e');
      return null;
    }
  }

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Get user email
  String? get userEmail => currentUser?.email;

  // Update user profile
  Future<String?> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.updatePhotoURL(photoURL);
      return null;
    } catch (e) {
      return 'Failed to update profile';
    }
  }

  // Change password
  Future<String?> changePassword(String newPassword) async {
    try {
      await currentUser?.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }
}