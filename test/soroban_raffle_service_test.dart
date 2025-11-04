import 'package:flutter_test/flutter_test.dart';
import 'package:azixflutter/services/soroban_raffle_service.dart';

void main() {
  group('SorobanRaffleService Tests', () {
    test('Service initialization should complete without errors', () async {
      // Test that initialization doesn't throw exceptions
      expect(
        () async => await SorobanRaffleService.initialize(),
        returnsNormally,
      );
    });

    test('Balance verification should return proper structure', () async {
      final result = await SorobanRaffleService.verifyAkofaBalance(
        userId: 'test_user',
        requiredAmount: 100.0,
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('success'), true);
      expect(result.containsKey('hasWallet'), true);
    });

    test('Raffle entry should handle missing wallet gracefully', () async {
      final result = await SorobanRaffleService.enterRaffle(
        raffleId: 'test_raffle',
        userId: 'test_user',
        password: 'test_password',
        entryAmount: 50.0,
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['success'], false);
      expect(result['error'], contains('wallet'));
    });

    test('Winner selection should return proper structure', () async {
      final result = await SorobanRaffleService.drawWinners(
        raffleId: 'test_raffle',
        numberOfWinners: 1,
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['success'], true);
      expect(result.containsKey('winners'), true);
    });

    test('Prize claiming should handle invalid winner ID', () async {
      final result = await SorobanRaffleService.claimPrize(
        winnerId: 'invalid_winner',
        userId: 'test_user',
        password: 'test_password',
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['success'], false);
    });

    test('Transaction status check should handle invalid hash', () async {
      final result = await SorobanRaffleService.checkTransactionStatus(
        'invalid_hash',
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result['success'], false);
    });

    test('Network status should return connection info', () async {
      final result = await SorobanRaffleService.getNetworkStatus();

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('success'), true);
      expect(result.containsKey('contractId'), true);
      expect(result.containsKey('akofaTokenId'), true);
    });

    test('Explorer URL generation should work correctly', () {
      const testHash = 'test_transaction_hash';
      final url = SorobanRaffleService.getTransactionExplorerUrl(testHash);

      expect(url, contains(testHash));
      expect(url, contains('stellar.expert'));
    });

    test('Soroban explorer URL should be valid', () {
      const testContractId = 'test_contract_id';
      final url = SorobanRaffleService.getSorobanExplorerUrl(testContractId);

      expect(url, contains(testContractId));
      expect(url, contains('contract'));
    });
  });
}
