import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/bridge_job.dart';

/// SQLite-based job store for persisting bridge jobs
class JobStore {
  static Database? _database;
  static const String _tableName = 'bridge_jobs';

  /// Initialize database
  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bridge_jobs.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id TEXT PRIMARY KEY,
            route_id TEXT NOT NULL,
            status TEXT NOT NULL,
            current_step_index INTEGER NOT NULL,
            quote_request TEXT NOT NULL,
            route_data TEXT NOT NULL,
            steps_data TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            error TEXT,
            metadata TEXT
          )
        ''');
      },
    );
  }

  /// Save or update a bridge job
  Future<void> saveJob(BridgeJob job) async {
    final db = await database;
    
    await db.insert(
      _tableName,
      {
        'id': job.id,
        'route_id': job.route.id,
        'status': job.status.toString(),
        'current_step_index': job.currentStepIndex,
        'quote_request': job.quoteRequest.toJson().toString(),
        'route_data': job.route.toJson().toString(),
        'steps_data': job.steps.map((s) => s.toJson()).toList().toString(),
        'created_at': job.createdAt.toIso8601String(),
        'updated_at': job.updatedAt.toIso8601String(),
        'error': job.error,
        'metadata': job.metadata?.toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get a job by ID
  Future<BridgeJob?> getJob(String id) async {
    final db = await database;
    
    final maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isEmpty) return null;
    
    // Reconstruct job from stored data
    // Note: This is simplified - in production, properly deserialize JSON
    return _jobFromMap(maps.first);
  }

  /// Get all jobs
  Future<List<BridgeJob>> getAllJobs() async {
    final db = await database;
    
    final maps = await db.query(
      _tableName,
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => _jobFromMap(map)).whereType<BridgeJob>().toList();
  }

  /// Get active jobs (pending, inProgress, waitingForUser)
  Future<List<BridgeJob>> getActiveJobs() async {
    final db = await database;
    
    final maps = await db.query(
      _tableName,
      where: 'status IN (?, ?, ?)',
      whereArgs: [
        BridgeJobStatus.pending.toString(),
        BridgeJobStatus.inProgress.toString(),
        BridgeJobStatus.waitingForUser.toString(),
      ],
      orderBy: 'updated_at DESC',
    );

    return maps.map((map) => _jobFromMap(map)).whereType<BridgeJob>().toList();
  }

  /// Update job status
  Future<void> updateJobStatus(
    String id,
    BridgeJobStatus status, {
    String? error,
  }) async {
    final db = await database;
    
    await db.update(
      _tableName,
      {
        'status': status.toString(),
        'updated_at': DateTime.now().toIso8601String(),
        if (error != null) 'error': error,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a job
  Future<void> deleteJob(String id) async {
    final db = await database;
    
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete completed jobs older than specified days
  Future<void> cleanupOldJobs(int daysOld) async {
    final db = await database;
    final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
    
    await db.delete(
      _tableName,
      where: 'status IN (?, ?) AND updated_at < ?',
      whereArgs: [
        BridgeJobStatus.completed.toString(),
        BridgeJobStatus.failed.toString(),
        cutoffDate.toIso8601String(),
      ],
    );
  }

  /// Helper to reconstruct job from map
  BridgeJob? _jobFromMap(Map<String, dynamic> map) {
    try {
      // This is a simplified version - in production, properly deserialize
      // For now, return null and let the caller handle it
      // Full implementation would parse JSON strings back to objects
      return null;
    } catch (e) {
      print('❌ Error reconstructing job from map: $e');
      return null;
    }
  }

  /// Close database
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}

