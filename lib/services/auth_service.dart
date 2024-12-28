// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/milestone_claim.dart';
import '../models/payment_details.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Authentication Methods
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Check for pending claims on login
      await _checkPendingClaims();
      
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
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Initialize user data in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
        'totalEarnings': 0,
        'lastClaimedAt': null,
      });

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

  // Payment Details Management
  Future<PaymentDetails?> getPaymentDetails() async {
    try {
      if (currentUser == null) return null;

      final doc = await _firestore
          .collection('payment_details')
          .doc(currentUser!.uid)
          .get();

      if (!doc.exists) return null;
      return PaymentDetails.fromFirestore(doc);
    } catch (e) {
      print('Error getting payment details: $e');
      return null;
    }
  }

  Future<void> updatePaymentDetails(PaymentDetails details) async {
    try {
      if (currentUser == null) throw Exception('Not authenticated');

      await _firestore
          .collection('payment_details')
          .doc(currentUser!.uid)
          .set(details.toMap(), SetOptions(merge: true));

      notifyListeners();
    } catch (e) {
      print('Error updating payment details: $e');
      throw Exception('Failed to update payment details');
    }
  }

  // Milestone Claims Management
  Future<void> claimMilestone(String videoId, int level, double amount) async {
    try {
      if (currentUser == null) throw Exception('Not authenticated');

      // First check if payment details exist
      final paymentDetails = await getPaymentDetails();
      if (paymentDetails == null || !paymentDetails.isComplete) {
        throw Exception('Please add payment details before claiming');
      }

      // Start a transaction to ensure data consistency
      await _firestore.runTransaction((transaction) async {
        // Get the video document
        final videoDoc = await transaction.get(
          _firestore.collection('videos').doc(videoId)
        );

        if (!videoDoc.exists) {
          throw Exception('Video not found');
        }

        final videoData = videoDoc.data()!;
        final views = videoData['views'] as int;
        final lastClaimedLevel = videoData['lastClaimedLevel'] as int? ?? 0;
        final claimedMilestones = List<String>.from(videoData['claimedMilestones'] ?? []);

        // Validate the claim
        if (level <= lastClaimedLevel) {
          throw Exception('This milestone has already been claimed');
        }

        if (claimedMilestones.contains(level.toString())) {
          throw Exception('This milestone has already been claimed');
        }

        // Create the claim
        final claimRef = _firestore.collection('milestone_claims').doc();
        transaction.set(claimRef, {
          'videoId': videoId,
          'userId': currentUser!.uid,
          'level': level,
          'amount': amount,
          'viewCount': views,
          'status': ClaimStatus.pending.name,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Update the video
        transaction.update(videoDoc.reference, {
          'lastClaimedLevel': level,
          'claimedMilestones': FieldValue.arrayUnion([level.toString()]),
          'isProcessingClaim': true,
        });

        // Update user's total pending claims
        transaction.update(
          _firestore.collection('users').doc(currentUser!.uid),
          {
            'pendingClaims': FieldValue.increment(1),
            'totalPendingAmount': FieldValue.increment(amount),
          },
        );
      });

      notifyListeners();
    } catch (e) {
      print('Error claiming milestone: $e');
      throw Exception('Failed to claim milestone: $e');
    }
  }

  Future<void> _checkPendingClaims() async {
    if (currentUser == null) return;

    try {
      final claims = await _firestore
          .collection('milestone_claims')
          .where('userId', isEqualTo: currentUser!.uid)
          .where('status', isEqualTo: ClaimStatus.approved.name)
          .get();

      for (var claim in claims.docs) {
        print('Found approved claim: ${claim.id}');
      }
    } catch (e) {
      print('Error checking pending claims: $e');
    }
  }

  Stream<List<MilestoneClaim>> getUserClaims() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('milestone_claims')
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
          snapshot.docs.map((doc) => MilestoneClaim.fromFirestore(doc)).toList()
        );
  }

  // Profile Management
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

  // User Statistics
  Future<Map<String, dynamic>> getUserStats() async {
    try {
      if (currentUser == null) throw Exception('Not authenticated');

      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();

      return {
        'totalEarnings': userDoc.data()?['totalEarnings'] ?? 0,
        'pendingClaims': userDoc.data()?['pendingClaims'] ?? 0,
        'totalPendingAmount': userDoc.data()?['totalPendingAmount'] ?? 0,
      };
    } catch (e) {
      print('Error getting user stats: $e');
      return {
        'totalEarnings': 0,
        'pendingClaims': 0,
        'totalPendingAmount': 0,
      };
    }
  }
}