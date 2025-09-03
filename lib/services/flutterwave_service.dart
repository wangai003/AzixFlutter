import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/stellar_provider.dart';
import '../providers/auth_provider.dart';
import '../config/flutterwave_config.dart';
import 'transaction_service.dart';

class FlutterwaveService {
  static Future<Map<String, dynamic>> initiatePayment({
    required BuildContext context,
    required double amountInUSD,
    required String paymentMethod,
    required String phoneNumber,
    required String email,
    required String name,
  }) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final stellarProvider = Provider.of<StellarProvider>(context, listen: false);
      
      if (authProvider.user == null) {
        return {'success': false, 'message': 'User not authenticated'};
      }
      
      // Validate amount limits
      if (amountInUSD < FlutterwaveConfig.minTransactionAmount || 
          amountInUSD > FlutterwaveConfig.maxTransactionAmount) {
        return {
          'success': false, 
          'message': 'Amount must be between \$${FlutterwaveConfig.minTransactionAmount} and \$${FlutterwaveConfig.maxTransactionAmount}'
        };
      }
      
      // Check payment method specific limits
      final methodLimits = FlutterwaveConfig.paymentLimits[paymentMethod];
      if (methodLimits != null) {
        if (amountInUSD < methodLimits['min']! || amountInUSD > methodLimits['max']!) {
          return {
            'success': false,
            'message': 'Amount must be between \$${methodLimits['min']} and \$${methodLimits['max']} for $paymentMethod'
          };
        }
      }
      
      // Calculate Akofa coins based on USD amount
      final akofaCoins = amountInUSD / FlutterwaveConfig.akofaRate;
      
      // IMPORTANT: Stellar only supports up to 7 decimal places
      // Round to 7 decimal places to avoid "decimal point cannot exceed seven digits" error
      final roundedAkofaCoins = double.parse(akofaCoins.toStringAsFixed(7));
      
      print('💰 Calculated AKOFA: $akofaCoins');
      print('🔢 Rounded to 7 decimals: $roundedAkofaCoins');
      
      // Create unique transaction reference
      final transactionRef = 'AKOFA_${DateTime.now().millisecondsSinceEpoch}_${authProvider.user!.uid}';
      
      // Simulate payment processing (in real implementation, this would integrate with Flutterwave)
      // Using sandbox credentials: clientId, clientSecret, encryptionKey
      await Future.delayed(const Duration(seconds: 3));
      
      // Simulate successful payment
      final paymentSuccess = true; // In real implementation, this would come from Flutterwave
      
      if (paymentSuccess) {
        // CRITICAL: Complete REAL Stellar on-chain transaction FIRST before recording anything
        try {
          // Ensure wallet is loaded and ready
          await stellarProvider.loadWalletAssets();
          
          // Get initial balance before transaction
          final initialBalance = stellarProvider.akofaBalance;
          double initialBalanceValue = 0.0;
          try {
            initialBalanceValue = double.tryParse(initialBalance.toString()) ?? 0.0;
          } catch (e) {
            initialBalanceValue = 0.0;
          }
          
          print('🔄 Initial AKOFA balance: $initialBalanceValue');
          
          // Credit user with Akofa coins - this performs REAL on-chain Stellar transaction
          print('🚀 Initiating REAL Stellar transaction for ${roundedAkofaCoins.toStringAsFixed(7)} AKOFA...');
          final creditResult = await stellarProvider.creditUserAsset('AKOFA', roundedAkofaCoins);
          
          // Check if the Stellar transaction actually succeeded
          if (creditResult['success'] != true) {
            print('❌ Stellar transaction failed: ${creditResult['message']}');
            return {
              'success': false,
              'message': 'Stellar blockchain transaction failed: ${creditResult['message']}',
            };
          }
          
          print('✅ Stellar transaction confirmed! Hash: ${creditResult['hash']}');
          
          // Wait a moment for blockchain confirmation
          await Future.delayed(const Duration(seconds: 2));
          
          // Get the updated balance to confirm the transaction
          await stellarProvider.refreshBalance();
          final newBalance = stellarProvider.akofaBalance;
          
          // Convert balance to double and verify it was actually updated
          double balanceValue;
          try {
            balanceValue = double.tryParse(newBalance.toString()) ?? 0.0;
          } catch (e) {
            balanceValue = 0.0;
          }
          
          print('🔄 New AKOFA balance: $balanceValue');
          print('🔄 Balance change: ${balanceValue - initialBalanceValue}');
          
          // Verify the balance was actually updated on-chain
          if (balanceValue <= initialBalanceValue) {
            print('❌ Balance not updated on-chain! Initial: $initialBalanceValue, New: $balanceValue');
            return {
              'success': false,
              'message': 'Stellar blockchain transaction failed. Balance not updated. Please try again.',
            };
          }
          
          // Verify the exact amount was added
          final expectedBalance = initialBalanceValue + roundedAkofaCoins;
          final tolerance = 0.0000001; // Allow small rounding differences (7 decimal precision)
          if ((balanceValue - expectedBalance).abs() > tolerance) {
            print('❌ Balance mismatch! Expected: $expectedBalance, Actual: $balanceValue');
            return {
              'success': false,
              'message': 'Stellar transaction amount mismatch. Expected: ${expectedBalance.toStringAsFixed(7)}, Got: ${balanceValue.toStringAsFixed(7)}',
            };
          }
          
          print('✅ Stellar transaction confirmed! Balance updated from $initialBalanceValue to $balanceValue');
          
          // Generate a unique transaction hash for this operation
          final transactionHash = creditResult['hash'] ?? 'STELLAR_${DateTime.now().millisecondsSinceEpoch}_${authProvider.user!.uid}';
          
          // ONLY NOW record transaction in Firestore AFTER Stellar transaction is confirmed on-chain
          await TransactionService.recordBuyAkofa(
            amount: roundedAkofaCoins,
            paymentMethod: paymentMethod,
            flutterwaveRef: transactionRef,
            stellarHash: transactionHash,
            additionalMetadata: {
              'amountInUSD': amountInUSD,
              'akofaRate': FlutterwaveConfig.akofaRate,
              'initialBalance': initialBalanceValue,
              'newBalance': balanceValue,
              'balanceChange': balanceValue - initialBalanceValue,
            },
          );
          
          // CRITICAL: Refresh transactions from blockchain to show the new transaction immediately
          print('🔄 Refreshing transactions from blockchain to show new purchase...');
          await stellarProvider.refreshTransactionsAfterOperation();
          
          return {
            'success': true,
            'message': 'Payment successful! ${roundedAkofaCoins.toStringAsFixed(7)} Akofa coins credited to your wallet. New balance: ${balanceValue.toStringAsFixed(7)} AKOFA',
            'akofaCoins': roundedAkofaCoins,
            'transactionRef': transactionRef,
            'stellarHash': transactionHash,
            'newBalance': balanceValue,
            'initialBalance': initialBalanceValue,
            'balanceChange': balanceValue - initialBalanceValue,
          };
          
        } catch (stellarError) {
          // If Stellar transaction fails, don't record anything
          print('❌ Stellar transaction failed: $stellarError');
          return {
            'success': false,
            'message': 'Stellar blockchain transaction failed: $stellarError. Please try again.',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Payment was not successful. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Payment error: $e',
      };
    }
  }
  
  // Get available payment methods
  static List<Map<String, dynamic>> getAvailablePaymentMethods() {
    return [
      {
        'id': 'mpesa',
        'name': 'M-Pesa',
        'description': 'Mobile money payment via M-Pesa',
        'icon': Icons.phone_android,
        'color': Colors.green,
        'minAmount': FlutterwaveConfig.paymentLimits['mpesa']!['min']!,
        'maxAmount': FlutterwaveConfig.paymentLimits['mpesa']!['max']!,
      },
      {
        'id': 'card',
        'name': 'Credit/Debit Card',
        'description': 'Pay with Visa, Mastercard, or other cards',
        'icon': Icons.credit_card,
        'color': Colors.blue,
        'minAmount': FlutterwaveConfig.paymentLimits['card']!['min']!,
        'maxAmount': FlutterwaveConfig.paymentLimits['card']!['max']!,
      },
      {
        'id': 'bank',
        'name': 'Bank Transfer',
        'description': 'Direct bank transfer',
        'icon': Icons.account_balance,
        'color': Colors.orange,
        'minAmount': FlutterwaveConfig.paymentLimits['bank']!['min']!,
        'maxAmount': FlutterwaveConfig.paymentLimits['bank']!['max']!,
      },
      {
        'id': 'ussd',
        'name': 'USSD',
        'description': 'USSD banking payment',
        'icon': Icons.phone,
        'color': Colors.purple,
        'minAmount': FlutterwaveConfig.paymentLimits['ussd']!['min']!,
        'maxAmount': FlutterwaveConfig.paymentLimits['ussd']!['max']!,
      },
      {
        'id': 'qr',
        'name': 'QR Code',
        'description': 'Scan QR code to pay',
        'icon': Icons.qr_code,
        'color': Colors.indigo,
        'minAmount': FlutterwaveConfig.paymentLimits['qr']!['min']!,
        'maxAmount': FlutterwaveConfig.paymentLimits['qr']!['max']!,
      },
    ];
  }
}
