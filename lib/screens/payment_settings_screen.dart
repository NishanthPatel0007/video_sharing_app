// lib/screens/payment_settings_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/payment_details.dart';
import '../services/auth_service.dart';

class PaymentSettingsScreen extends StatefulWidget {
  const PaymentSettingsScreen({Key? key}) : super(key: key);

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  PaymentMethod _selectedMethod = PaymentMethod.both;
  
  // Controllers for form fields
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _accountHolderController = TextEditingController();
  final _upiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadExistingPaymentDetails();
  }

  Future<void> _loadExistingPaymentDetails() async {
    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId != null) {
      final doc = await FirebaseFirestore.instance
          .collection('paymentDetails')
          .doc(userId)
          .get();
      
      if (doc.exists) {
        final details = PaymentDetails.fromFirestore(doc);
        setState(() {
          _bankNameController.text = details.bankName ?? '';
          _accountNumberController.text = details.bankAccount ?? '';
          _ifscController.text = details.ifscCode ?? '';
          _accountHolderController.text = details.accountHolderName ?? '';
          _upiController.text = details.upiId ?? '';
          _selectedMethod = details.preferredMethod;
        });
      }
    }
  }

  Future<void> _savePaymentDetails() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = context.read<AuthService>().currentUser?.uid;
    if (userId == null) return;

    final details = PaymentDetails(
      userId: userId,
      bankName: _bankNameController.text,
      bankAccount: _accountNumberController.text,
      ifscCode: _ifscController.text,
      accountHolderName: _accountHolderController.text,
      upiId: _upiController.text,
      preferredMethod: _selectedMethod,
    );

    try {
      await FirebaseFirestore.instance
          .collection('paymentDetails')
          .doc(userId)
          .set(details.toMap(), SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment details saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving payment details: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Payment Method Preference',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              // Payment method selection
              DropdownButtonFormField<PaymentMethod>(
                value: _selectedMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Color(0xFF2D2940),
                ),
                dropdownColor: const Color(0xFF2D2940),
                style: const TextStyle(color: Colors.white),
                items: PaymentMethod.values.map((method) {
                  return DropdownMenuItem(
                    value: method,
                    child: Text(method.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMethod = value);
                  }
                },
              ),
              const SizedBox(height: 24),
              
              // Bank Details Section
              if (_selectedMethod != PaymentMethod.upi) ...[
                const Text(
                  'Bank Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF2D2940),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _accountNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Account Number',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF2D2940),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ifscController,
                  decoration: const InputDecoration(
                    labelText: 'IFSC Code',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF2D2940),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _accountHolderController,
                  decoration: const InputDecoration(
                    labelText: 'Account Holder Name',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF2D2940),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],

              // UPI Section
              if (_selectedMethod != PaymentMethod.bankTransfer) ...[
                const SizedBox(height: 24),
                const Text(
                  'UPI Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _upiController,
                  decoration: const InputDecoration(
                    labelText: 'UPI ID',
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Color(0xFF2D2940),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savePaymentDetails,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Save Payment Details'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _accountHolderController.dispose();
    _upiController.dispose();
    super.dispose();
  }
}