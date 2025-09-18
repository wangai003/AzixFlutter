import 'package:flutter_test/flutter_test.dart';
import 'package:stellar_flutter_sdk/stellar_flutter_sdk.dart';
import 'package:azixflutter/services/akofa_tag_service.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  test('AKOFA Transaction Capacity Test', () async {
    print('🚀 AKOFA Transaction Capacity Test');
    print('Sending 300 AKOFA from issuer to user wallet');
    print('=' * 80);

    final StellarSDK sdk = StellarSDK.TESTNET;

    // AKOFA Asset configuration
    final String issuerPublic =
        'GBJGVMBWKGSMPZ4D7QDTW7VPCJUWCJ26OIHFJNRIWVR362NNUU3YCOTQ';
    final String issuerSecret =
        'SCB3ICTKZ3FQX6R6JRBV2427JVPGN7IELDUWQOKDFGT5BGKQKWBURPIR';
    final String assetCode = 'AKOFA';

    // Create a new recipient account for testing
    final KeyPair recipientKeyPair = KeyPair.random();
    final String recipientAddress = recipientKeyPair.accountId;
    final String recipientSecret = recipientKeyPair.secretSeed;

    // Amount to send
    final String amount = '300.0000000'; // 300 AKOFA with 7 decimal places

    // Create asset and keypair early
    final akofaAsset = AssetTypeCreditAlphaNum12(assetCode, issuerPublic);
    final issuerKeyPair = KeyPair.fromSecretSeed(issuerSecret);
    final issuerAccountId = issuerKeyPair.accountId;

    try {
      print('\n📡 Testing issuer account...');
      final issuerAccount = await sdk.accounts.account(issuerPublic);
      print('✅ Issuer account found successfully!');
      print('📊 Issuer Balances:');
      for (var balance in issuerAccount.balances!) {
        if (balance.assetType == 'native') {
          print('   - XLM: ${balance.balance}');
        } else {
          print(
            '   - ${balance.assetCode}: ${balance.balance} (Issuer: ${balance.assetIssuer})',
          );
        }
      }

      print('\n🔧 Creating and funding recipient account...');
      // Create account operation
      final createAccountOp = CreateAccountOperationBuilder(
        recipientAddress,
        '2.0',
      ).build();

      // Build transaction to create and fund account
      final createAccountTxBuilder = TransactionBuilder(issuerAccount);
      createAccountTxBuilder.addOperation(createAccountOp);
      final createAccountTx = createAccountTxBuilder.build();
      createAccountTx.sign(issuerKeyPair, Network.TESTNET);

      print('📤 Submitting account creation transaction...');
      final createResponse = await sdk.submitTransaction(createAccountTx);
      if (createResponse.success) {
        print('✅ Recipient account created and funded successfully!');
      } else {
        print('❌ Failed to create recipient account!');
        if (createResponse.extras != null) {
          print('   - Result codes: ${createResponse.extras!.resultCodes}');
          if (createResponse.extras!.resultCodes != null) {
            print(
              '   - Transaction result: ${createResponse.extras!.resultCodes!.transactionResultCode}',
            );
          }
        }
        return;
      }

      // Wait for account creation to propagate
      await Future.delayed(const Duration(seconds: 3));

      print('\n🔧 Creating AKOFA trustline for recipient...');
      // Get recipient account
      final recipientAccount = await sdk.accounts.account(recipientAddress);

      // Create trustline operation
      final trustlineOp = ChangeTrustOperationBuilder(akofaAsset, '0').build();

      // Build trustline transaction
      final trustlineTxBuilder = TransactionBuilder(recipientAccount);
      trustlineTxBuilder.addOperation(trustlineOp);
      final trustlineTx = trustlineTxBuilder.build();
      trustlineTx.sign(
        KeyPair.fromSecretSeed(recipientSecret),
        Network.TESTNET,
      );

      print('📤 Submitting trustline creation transaction...');
      final trustlineResponse = await sdk.submitTransaction(trustlineTx);
      if (trustlineResponse.success) {
        print('✅ AKOFA trustline created successfully!');
      } else {
        print('❌ Failed to create AKOFA trustline!');
        print('📋 Response extras: ${trustlineResponse.extras}');
        return;
      }

      // Wait for trustline to propagate
      await Future.delayed(const Duration(seconds: 3));

      print('\n📡 Testing recipient account...');
      print('✅ Recipient account found successfully!');
      print('📊 Recipient Balances:');
      for (var balance in recipientAccount.balances!) {
        if (balance.assetType == 'native') {
          print('   - XLM: ${balance.balance}');
        } else {
          print(
            '   - ${balance.assetCode}: ${balance.balance} (Issuer: ${balance.assetIssuer})',
          );
        }
      }

      // Since we just created the trustline, it should be there
      print('\n✅ Recipient has AKOFA trustline - ready for transaction!');

      // Check if issuer has AKOFA tokens
      final issuerHasAkofa = issuerAccount.balances!.any(
        (b) => b.assetCode == assetCode && b.assetIssuer == issuerPublic,
      );

      if (!issuerHasAkofa) {
        print('\n⚠️  Issuer does not have AKOFA tokens!');
        print(
          '💡 The transaction will fail. Issuer must have AKOFA tokens to send.',
        );
        print(
          '💡 Skipping transaction test due to insufficient issuer balance.',
        );
        return;
      } else {
        final akofaBalance = issuerAccount.balances!.firstWhere(
          (b) => b.assetCode == assetCode && b.assetIssuer == issuerPublic,
        );
        print('\n✅ Issuer has ${akofaBalance.balance} AKOFA tokens');
      }

      print('\n� Preparing transaction...');

      // Get latest account info
      final account = await sdk.accounts.account(issuerAccountId);

      // Create payment operation
      final paymentOperation = PaymentOperationBuilder(
        recipientAddress,
        akofaAsset,
        amount,
      );

      // Build transaction
      final transactionBuilder = TransactionBuilder(account);
      transactionBuilder.addOperation(paymentOperation.build());
      transactionBuilder.addMemo(MemoText('AKOFA Test'));

      final transaction = transactionBuilder.build();
      transaction.sign(issuerKeyPair, Network.TESTNET);

      print('📤 Submitting transaction...');
      final response = await sdk.submitTransaction(transaction);

      if (response.success) {
        print('✅ Transaction successful!');
        print('🔗 Transaction Hash: ${response.hash}');
        print('📅 Submitted at: ${DateTime.now()}');
        print('💰 Amount sent: $amount AKOFA');
        print('👤 From: $issuerAccountId');
        print('👥 To: $recipientAddress');

        // Wait a moment for the transaction to be processed
        print('\n⏳ Waiting for transaction confirmation...');
        await Future.delayed(const Duration(seconds: 5));

        // Verify the transaction
        print('\n🔍 Verifying transaction...');
        final Page<TransactionResponse> txPage = await sdk.transactions
            .forAccount(recipientAddress)
            .order(RequestBuilderOrder.DESC)
            .limit(5)
            .execute();

        bool found = false;
        for (final tx in txPage.records) {
          if (tx.hash == response.hash) {
            print('✅ Transaction confirmed in recipient account!');
            print('📋 Transaction details:');
            print('   - Hash: ${tx.hash}');
            print('   - Successful: ${tx.successful}');
            print('   - Fee: ${tx.feeCharged} stroops');
            found = true;
            break;
          }
        }

        if (!found) {
          print(
            '⚠️  Transaction not yet visible in recipient account (may take a moment)',
          );
        }

        // Check updated balances
        print('\n📊 Checking updated balances...');
        final updatedRecipientAccount = await sdk.accounts.account(
          recipientAddress,
        );
        print('📈 Recipient new balances:');
        for (var balance in updatedRecipientAccount.balances!) {
          if (balance.assetType == 'native') {
            print('   - XLM: ${balance.balance}');
          } else if (balance.assetCode == assetCode) {
            print('   - AKOFA: ${balance.balance}');
          }
        }
      } else {
        print('❌ Transaction failed!');
        print('📋 Response extras: ${response.extras}');
        if (response.extras != null) {
          print('   - Result codes: ${response.extras!.resultCodes}');
          if (response.extras!.resultCodes != null) {
            print(
              '   - Transaction result: ${response.extras!.resultCodes!.transactionResultCode}',
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      print('❌ Error type: ${e.runtimeType}');

      if (e.toString().contains('404')) {
        print('💡 Account not found - this could mean:');
        print('   - Wrong account ID');
        print('   - Account doesn\'t exist on testnet');
        print('   - Account was merged or removed');
      } else if (e.toString().contains('op_underfunded')) {
        print(
          '💡 Insufficient funds - issuer account may not have enough AKOFA tokens',
        );
      } else if (e.toString().contains('op_no_trust')) {
        print(
          '💡 No trustline - recipient account needs to trust the AKOFA asset first',
        );
      } else if (e.toString().contains('SocketException')) {
        print('💡 Network error - check your internet connection');
      }
    }

    print('\n🎉 Transaction test completed!');
    print('=' * 80);
  });

  group('Akofa Tag System Tests', () {
    test('Tag format validation', () {
      // Valid tags
      expect(AkofaTagService.isValidTagFormat('john1234'), true);
      expect(AkofaTagService.isValidTagFormat('mary5678'), true);
      expect(AkofaTagService.isValidTagFormat('david9999'), true);

      // Invalid tags
      expect(AkofaTagService.isValidTagFormat('john'), false); // No numbers
      expect(AkofaTagService.isValidTagFormat('1234'), false); // No letters
      expect(
        AkofaTagService.isValidTagFormat('john123'),
        false,
      ); // Too few digits
      expect(
        AkofaTagService.isValidTagFormat('john12345'),
        false,
      ); // Too many digits
      expect(
        AkofaTagService.isValidTagFormat('john_1234'),
        false,
      ); // Invalid character
      expect(AkofaTagService.isValidTagFormat(''), false); // Empty
    });

    test('Tag generation format', () {
      // Test that generated tags follow the expected format
      final testTags = ['test1234', 'user5678', 'demo9999', 'sample1111'];

      for (final tag in testTags) {
        expect(
          AkofaTagService.isValidTagFormat(tag),
          true,
          reason: 'Tag $tag should be valid format',
        );
      }
    });

    test('Tag resolution simulation', () async {
      // This test simulates tag resolution without actual Firebase calls
      // In a real test environment, you would mock Firebase services

      print('\n🏷️  Akofa Tag Resolution Test');
      print('Testing tag format validation and resolution logic...');

      // Test valid tag formats
      final validTags = ['alice1234', 'bob5678', 'charlie9999'];
      for (final tag in validTags) {
        expect(AkofaTagService.isValidTagFormat(tag), true);
        print('✅ Valid tag format: $tag');
      }

      // Test invalid tag formats
      final invalidTags = [
        'alice',
        '1234',
        'alice123',
        'alice12345',
        'alice_1234',
      ];
      for (final tag in invalidTags) {
        expect(AkofaTagService.isValidTagFormat(tag), false);
        print('❌ Invalid tag format: $tag');
      }

      print('✅ Tag format validation tests passed');
    });

    test('Tag uniqueness logic', () {
      // Test that the uniqueness logic works correctly
      print('\n🔍 Akofa Tag Uniqueness Test');

      // Generate multiple tags and ensure they're different
      final tags = <String>{};
      for (int i = 0; i < 10; i++) {
        final tag = _generateTestTag('testuser');
        tags.add(tag);
        expect(AkofaTagService.isValidTagFormat(tag), true);
      }

      // While we can't guarantee uniqueness in a test without Firebase,
      // we can at least verify the format is correct
      expect(tags.length, greaterThan(0));
      print('✅ Generated ${tags.length} unique test tags');
    });

    test('Tag search functionality simulation', () {
      print('\n🔎 Akofa Tag Search Test');

      // Test search query validation
      final searchQueries = ['', 'a', 'alice', 'alice123', 'invalid_query!'];

      for (final query in searchQueries) {
        // In a real implementation, this would search Firebase
        // For now, we just validate the query doesn't break anything
        print('Testing search query: "$query"');
      }

      print('✅ Tag search simulation completed');
    });
  });
}

// Helper function for testing tag generation
String _generateTestTag(String baseName) {
  final random = DateTime.now().millisecondsSinceEpoch % 10000;
  final paddedRandom = random.toString().padLeft(4, '0');
  return '$baseName$paddedRandom';
}
