// lib/models/payment_details.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum PaymentMethod {
  bankTransfer,
  upi,
  both
}

class PaymentDetails {
  final String userId;
  final String? bankName;
  final String? bankAccount;
  final String? ifscCode;
  final String? accountHolderName;
  final String? upiId;
  final PaymentMethod preferredMethod;
  final DateTime? lastUpdated;
  final bool isVerified;
  final DateTime? verifiedAt;
  final String? verifiedBy;
  final int totalPayments;
  final double totalAmountPaid;
  final DateTime? lastPaidAt;
  final String? lastTransactionId;
  final Map<String, dynamic>? recentPayments;
  final Map<String, dynamic>? verificationData;

  PaymentDetails({
    required this.userId,
    this.bankName,
    this.bankAccount,
    this.ifscCode,
    this.accountHolderName,
    this.upiId,
    this.preferredMethod = PaymentMethod.both,
    this.lastUpdated,
    this.isVerified = false,
    this.verifiedAt,
    this.verifiedBy,
    this.totalPayments = 0,
    this.totalAmountPaid = 0.0,
    this.lastPaidAt,
    this.lastTransactionId,
    this.recentPayments,
    this.verificationData,
  });

  // Check if bank details are complete
  bool get hasBankDetails => 
      bankAccount != null && 
      bankAccount!.isNotEmpty && 
      ifscCode != null && 
      ifscCode!.isNotEmpty &&
      accountHolderName != null &&
      accountHolderName!.isNotEmpty;

  // Check if UPI details are complete
  bool get hasUpiDetails => 
      upiId != null && 
      upiId!.isNotEmpty;

  // Check if any payment method is available
  bool get isComplete => hasBankDetails || hasUpiDetails;

  // Get available payment methods
  List<PaymentMethod> get availableMethods {
    List<PaymentMethod> methods = [];
    if (hasBankDetails) methods.add(PaymentMethod.bankTransfer);
    if (hasUpiDetails) methods.add(PaymentMethod.upi);
    return methods;
  }

  // Create from Firestore document
  factory PaymentDetails.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PaymentDetails(
      userId: doc.id,
      bankName: data['bankName'],
      bankAccount: data['bankAccount'],
      ifscCode: data['ifscCode'],
      accountHolderName: data['accountHolderName'],
      upiId: data['upiId'],
      preferredMethod: PaymentMethod.values.firstWhere(
        (m) => m.name == (data['preferredMethod'] ?? 'both'),
        orElse: () => PaymentMethod.both,
      ),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate(),
      isVerified: data['isVerified'] ?? false,
      verifiedAt: (data['verifiedAt'] as Timestamp?)?.toDate(),
      verifiedBy: data['verifiedBy'],
      totalPayments: data['totalPayments'] ?? 0,
      totalAmountPaid: (data['totalAmountPaid'] ?? 0).toDouble(),
      lastPaidAt: (data['lastPaidAt'] as Timestamp?)?.toDate(),
      lastTransactionId: data['lastTransactionId'],
      recentPayments: data['recentPayments'],
      verificationData: data['verificationData'],
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'bankName': bankName,
      'bankAccount': bankAccount,
      'ifscCode': ifscCode,
      'accountHolderName': accountHolderName,
      'upiId': upiId,
      'preferredMethod': preferredMethod.name,
      'lastUpdated': FieldValue.serverTimestamp(),
      'isVerified': isVerified,
      if (verifiedAt != null) 'verifiedAt': Timestamp.fromDate(verifiedAt!),
      if (verifiedBy != null) 'verifiedBy': verifiedBy,
      'totalPayments': totalPayments,
      'totalAmountPaid': totalAmountPaid,
      if (lastPaidAt != null) 'lastPaidAt': Timestamp.fromDate(lastPaidAt!),
      if (lastTransactionId != null) 'lastTransactionId': lastTransactionId,
      if (recentPayments != null) 'recentPayments': recentPayments,
      if (verificationData != null) 'verificationData': verificationData,
    };
  }

  // Create a copy with updated fields
  PaymentDetails copyWith({
    String? bankName,
    String? bankAccount,
    String? ifscCode,
    String? accountHolderName,
    String? upiId,
    PaymentMethod? preferredMethod,
    DateTime? lastUpdated,
    bool? isVerified,
    DateTime? verifiedAt,
    String? verifiedBy,
    int? totalPayments,
    double? totalAmountPaid,
    DateTime? lastPaidAt,
    String? lastTransactionId,
    Map<String, dynamic>? recentPayments,
    Map<String, dynamic>? verificationData,
  }) {
    return PaymentDetails(
      userId: userId,
      bankName: bankName ?? this.bankName,
      bankAccount: bankAccount ?? this.bankAccount,
      ifscCode: ifscCode ?? this.ifscCode,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      upiId: upiId ?? this.upiId,
      preferredMethod: preferredMethod ?? this.preferredMethod,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isVerified: isVerified ?? this.isVerified,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      totalPayments: totalPayments ?? this.totalPayments,
      totalAmountPaid: totalAmountPaid ?? this.totalAmountPaid,
      lastPaidAt: lastPaidAt ?? this.lastPaidAt,
      lastTransactionId: lastTransactionId ?? this.lastTransactionId,
      recentPayments: recentPayments ?? this.recentPayments,
      verificationData: verificationData ?? this.verificationData,
    );
  }

  // Helper methods for payment history
  List<Map<String, dynamic>> getRecentPayments({int limit = 5}) {
    if (recentPayments == null) return [];
    final payments = List<Map<String, dynamic>>.from(recentPayments!['history'] ?? []);
    payments.sort((a, b) => (b['date'] as Timestamp).compareTo(a['date'] as Timestamp));
    return payments.take(limit).toList();
  }

  // Format amounts
  String formatAmount(double amount) {
    if (amount >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  // Validate bank account number
  bool isValidBankAccount() {
    if (bankAccount == null) return false;
    // Basic validation - can be expanded based on specific bank rules
    return bankAccount!.length >= 9 && bankAccount!.length <= 18;
  }

  // Validate IFSC code
  bool isValidIFSC() {
    if (ifscCode == null) return false;
    final regExp = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
    return regExp.hasMatch(ifscCode!);
  }

  // Validate UPI ID
  bool isValidUPI() {
    if (upiId == null) return false;
    final regExp = RegExp(r'^[\w.-]+@[\w.-]+$');
    return regExp.hasMatch(upiId!);
  }

  // Get masked account number for display
  String getMaskedAccountNumber() {
    if (bankAccount == null || bankAccount!.isEmpty) return '';
    if (bankAccount!.length <= 4) return bankAccount!;
    return 'XXXX${bankAccount!.substring(bankAccount!.length - 4)}';
  }

  // Get masked UPI ID for display
  String getMaskedUPI() {
    if (upiId == null || upiId!.isEmpty) return '';
    final parts = upiId!.split('@');
    if (parts.length != 2) return upiId!;
    final username = parts[0];
    if (username.length <= 2) return upiId!;
    return '${username[0]}***${username[username.length - 1]}@${parts[1]}';
  }
}