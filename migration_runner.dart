import 'dart:io';
import 'lib/services/akofa_tag_migration_service.dart';

/// Standalone script to run the AKOFA tag migration
/// Usage: dart migration_runner.dart [--dry-run] [--backup-file backup.json]
void main(List<String> args) async {
  print('🚀 AKOFA Tag Migration Runner');
  print('=' * 50);

  // Parse arguments
  bool dryRun = args.contains('--dry-run');
  String? backupFile;

  final backupIndex = args.indexOf('--backup-file');
  if (backupIndex != -1 && backupIndex + 1 < args.length) {
    backupFile = args[backupIndex + 1];
  }

  // Default backup file if not specified and not dry run
  if (!dryRun && backupFile == null) {
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    backupFile = 'akofa_migration_backup_$timestamp.json';
  }

  try {
    print('Configuration:');
    print('  Dry Run: $dryRun');
    print('  Backup File: ${backupFile ?? 'None'}');
    print('');

    // Run migration
    final result = await AkofaTagMigrationService.runMigration(
      dryRun: dryRun,
      backupFilePath: backupFile,
    );

    if (result['success'] == true) {
      print('✅ Migration completed successfully!');
      print('');
      print('Summary:');
      print('  Dry Run: ${result['dryRun']}');
      print('  Backup Created: ${result['backupCreated']}');

      final analysis = result['analysis'] as Map<String, dynamic>;
      print('  Total Users: ${analysis['totalUsers']}');
      print('  Users with Multiple Tags: ${analysis['usersWithMultipleTags']}');
      print('  Users with No Tags: ${analysis['usersWithNoTags']}');
      print(
        '  Users with Linked Wallets: ${analysis['usersWithLinkedWallets']}',
      );

      final results = result['results'] as Map<String, dynamic>;
      print('  Users Processed: ${results['processedUsers']}');
      print('  Tags Kept: ${results['tagsKept']}');
      print('  Tags Generated: ${results['tagsGenerated']}');
      print('  Tags Removed: ${results['tagsRemoved']}');

      final verification = result['verification'] as Map<String, dynamic>;
      print('  Migration Valid: ${verification['isValid']}');

      if (!verification['isValid']) {
        print('  ⚠️  Warning: Some issues remain after migration');
        print(
          '    Remaining Multiple Tags: ${verification['remainingMultipleTags']}',
        );
        print('    Remaining No Tags: ${verification['remainingNoTags']}');
      }

      if (backupFile != null) {
        print('');
        print('To rollback this migration, run:');
        print('dart migration_runner.dart --rollback $backupFile');
      }
    } else {
      print('❌ Migration failed: ${result['error']}');
      exit(1);
    }
  } catch (e) {
    print('❌ Unexpected error: $e');
    exit(1);
  }
}

/// Rollback migration
Future<void> rollbackMigration(String backupFile) async {
  print('🔄 Starting rollback from $backupFile...');

  try {
    final result = await AkofaTagMigrationService.rollbackMigration(backupFile);

    if (result['success'] == true) {
      print('✅ Rollback completed successfully!');
    } else {
      print('❌ Rollback failed: ${result['error']}');
      exit(1);
    }
  } catch (e) {
    print('❌ Unexpected error during rollback: $e');
    exit(1);
  }
}
