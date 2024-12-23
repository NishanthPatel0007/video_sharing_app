// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          return 'No user found with this email';
        case 'wrong-password':
          return 'Invalid password';
        case 'user-disabled':
          return 'This account has been disabled';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return 'Login failed: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  Future<String?> register(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      notifyListeners();
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'weak-password':
          return 'Password is too weak';
        case 'email-already-in-use':
          return 'Email is already in use';
        case 'invalid-email':
          return 'Invalid email address';
        default:
          return 'Registration failed: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      notifyListeners();
    } catch (e) {
      print('Sign out error: $e');
    }
  }

  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      print('Get token error: $e');
      return null;
    }
  }

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
          return 'Password reset failed: ${e.message}';
      }
    } catch (e) {
      return 'An unexpected error occurred';
    }
  }

  Future<String?> updateProfile({String? displayName, String? photoURL}) async {
    try {
      await currentUser?.updateDisplayName(displayName);
      await currentUser?.updatePhotoURL(photoURL);
      notifyListeners();
      return null;
    } catch (e) {
      return 'Failed to update profile';
    }
  }
}