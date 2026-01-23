import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MpesaService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // M-Pesa API endpoints
  static const String _baseUrl = 'https://sandbox.safaricom.co.ke';
  static const String _authUrl = '$_baseUrl/oauth/v1/generate?grant_type=client_credentials';
  // Daraja 3.0 uses the /process endpoint (processrequest was deprecated)
  static const String _stkPushUrl = '$_baseUrl/mpesa/stkpush/v1/process';
  static const String _queryUrl = '$_baseUrl/mpesa/stkpushquery/v1/query';
  
  // M-Pesa credentials - in production, these should be stored securely
  static const String _consumerKey = 'YOUR_CONSUMER_KEY';
  static const String _consumerSecret = 'YOUR_CONSUMER_SECRET';
  static const String _passKey = 'YOUR_PASS_KEY';
  static const String _shortCode = 'YOUR_SHORT_CODE';
  static const String _callbackUrl = 'YOUR_CALLBACK_URL';
  
  // Get OAuth token
  Future<String> _getAccessToken() async {
    final auth = 'Basic ${base64Encode(utf8.encode('$_consumerKey:$_consumerSecret'))}';
    
    try {
      final response = await http.get(
        Uri.parse(_authUrl),
        headers: {
          'Authorization': auth,
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['access_token'];
      } else {
        throw Exception('Failed to get access token: ${response.body}');
      }
    } catch (e) {
      throw Exception('Error getting access token: $e');
    }
  }
  
  // Generate timestamp in the format required by M-Pesa
  String _generateTimestamp() {
    final now = DateTime.now();
    final year = now.year.toString();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    
    return '$year$month$day$hour$minute$second';
  }
  
  // Generate password for STK Push
  String _generatePassword(String timestamp) {
    final dataToEncode = '$_shortCode$_passKey$timestamp';
    return base64Encode(utf8.encode(dataToEncode));
  }
  
  // Initiate STK Push
  Future<Map<String, dynamic>> initiateSTKPush(String phoneNumber, double amount, String accountReference) async {
    try {
      if (kDebugMode) {
      }
      
      // Format phone number (remove leading 0 or +254)
      if (phoneNumber.startsWith('0')) {
        phoneNumber = '254${phoneNumber.substring(1)}';
      } else if (phoneNumber.startsWith('+254')) {
        phoneNumber = phoneNumber.substring(1);
      }
      
      // Get access token
      final accessToken = await _getAccessToken();
      
      // Generate timestamp
      final timestamp = _generateTimestamp();
      
      // Generate password
      final password = _generatePassword(timestamp);
      
      // Prepare request body
      final body = {
        'BusinessShortCode': _shortCode,
        'Password': password,
        'Timestamp': timestamp,
        'TransactionType': 'CustomerPayBillOnline',
        'Amount': amount.round().toString(),
        'PartyA': phoneNumber,
        'PartyB': _shortCode,
        'PhoneNumber': phoneNumber,
        'CallBackURL': _callbackUrl,
        'AccountReference': accountReference,
        'TransactionDesc': 'Purchase of AKOFA tokens',
      };
      
      // Make API request
      final response = await http.post(
        Uri.parse(_stkPushUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
        }
        
        // Store transaction details in Firestore
        await _recordMpesaTransaction(
          phoneNumber,
          amount,
          data['CheckoutRequestID'],
          accountReference,
          'pending'
        );
        
        return {
          'success': true,
          'checkoutRequestId': data['CheckoutRequestID'],
          'responseCode': data['ResponseCode'],
          'customerMessage': data['CustomerMessage'],
        };
      } else {
        if (kDebugMode) {
        }
        
        return {
          'success': false,
          'error': 'Failed to initiate payment: ${response.body}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
      }
      
      return {
        'success': false,
        'error': 'Error initiating payment: $e',
      };
    }
  }
  
  // Query STK Push status
  Future<Map<String, dynamic>> querySTKStatus(String checkoutRequestId) async {
    try {
      // Get access token
      final accessToken = await _getAccessToken();
      
      // Generate timestamp
      final timestamp = _generateTimestamp();
      
      // Generate password
      final password = _generatePassword(timestamp);
      
      // Prepare request body
      final body = {
        'BusinessShortCode': _shortCode,
        'Password': password,
        'Timestamp': timestamp,
        'CheckoutRequestID': checkoutRequestId,
      };
      
      // Make API request
      final response = await http.post(
        Uri.parse(_queryUrl),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: json.encode(body),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (kDebugMode) {
        }
        
        // Update transaction status in Firestore
        if (data['ResultCode'] == '0') {
          await _updateMpesaTransactionStatus(checkoutRequestId, 'completed');
          
          // Credit the user's account with AKOFA tokens
          await _creditUserAccount(checkoutRequestId);
        } else {
          await _updateMpesaTransactionStatus(checkoutRequestId, 'failed');
        }
        
        return {
          'success': true,
          'resultCode': data['ResultCode'],
          'resultDesc': data['ResultDesc'],
        };
      } else {
        if (kDebugMode) {
        }
        
        return {
          'success': false,
          'error': 'Failed to query payment status: ${response.body}',
        };
      }
    } catch (e) {
      if (kDebugMode) {
      }
      
      return {
        'success': false,
        'error': 'Error querying payment status: $e',
      };
    }
  }
  
  // Record M-Pesa transaction in Firestore
  Future<DocumentReference> _recordMpesaTransaction(
    String phoneNumber,
    double amount,
    String checkoutRequestId,
    String accountReference,
    String status
  ) async {
    final String uid = _auth.currentUser!.uid;
    
    return await _firestore.collection('mpesa_transactions').add({
      'userId': uid,
      'phoneNumber': phoneNumber,
      'amount': amount,
      'checkoutRequestId': checkoutRequestId,
      'accountReference': accountReference,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
  
  // Update M-Pesa transaction status in Firestore
  Future<void> _updateMpesaTransactionStatus(String checkoutRequestId, String status) async {
    final querySnapshot = await _firestore.collection('mpesa_transactions')
      .where('checkoutRequestId', isEqualTo: checkoutRequestId)
      .get();
    
    if (querySnapshot.docs.isNotEmpty) {
      await querySnapshot.docs.first.reference.update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
  
  // Credit user account with AKOFA tokens after successful payment
  Future<void> _creditUserAccount(String checkoutRequestId) async {
    try {
      // Get the transaction details
      final querySnapshot = await _firestore.collection('mpesa_transactions')
        .where('checkoutRequestId', isEqualTo: checkoutRequestId)
        .limit(1)
        .get();
      
      if (querySnapshot.docs.isEmpty) {
        if (kDebugMode) {
        }
        return;
      }
      
      final transactionDoc = querySnapshot.docs.first;
      final transactionData = transactionDoc.data();
      
      // Calculate AKOFA tokens to credit (1 AKOFA = 5.52 KES)
      final double amount = transactionData['amount'] ?? 0.0;
      final double akofaAmount = amount / 5.52;
      
      // Get user ID
      final String userId = transactionData['userId'] ?? _auth.currentUser!.uid;
      
      // Update the transaction with the AKOFA amount
      await transactionDoc.reference.update({
        'akofaAmount': akofaAmount,
        'status': 'credited',
        'creditedAt': FieldValue.serverTimestamp(),
      });
      
      // TODO: Implement actual token transfer using Stellar SDK
      // This would involve:
      // 1. Getting the issuer account credentials
      // 2. Creating a payment transaction to the user's Stellar account
      // 3. Submitting the transaction to the Stellar network
      
      if (kDebugMode) {
      }
    } catch (e) {
      if (kDebugMode) {
      }
    }
  }
  
  // Get M-Pesa transaction history for current user
  Future<List<Map<String, dynamic>>> getMpesaTransactionHistory() async {
    try {
      final String uid = _auth.currentUser!.uid;
      
      final querySnapshot = await _firestore.collection('mpesa_transactions')
        .where('userId', isEqualTo: uid)
        .orderBy('timestamp', descending: true)
        .get();
      
      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      if (kDebugMode) {
      }
      return [];
    }
  }
}