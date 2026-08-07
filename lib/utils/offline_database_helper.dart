import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/api/api_client.dart';
import '../core/api/endpoints.dart';

class OfflineDatabaseHelper {
  static final OfflineDatabaseHelper instance = OfflineDatabaseHelper._init();
  static Database? _database;

  OfflineDatabaseHelper._init();

  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<Database?> get database async {
    if (!isSupported) return null;
    if (_database != null) return _database!;
    _database = await _initDB('offline_kots.db');
    return _database;
  }

  Future<Database?> _initDB(String filePath) async {
    if (!isSupported) return null;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_kots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        table_id INTEGER,
        service_type TEXT,
        waiter_id INTEGER,
        captain_id INTEGER,
        remarks TEXT,
        items TEXT,
        status TEXT
      )
    ''');
  }

  /// CACHE KOT LOCALLY
  Future<int> cacheKot(Map<String, dynamic> kotData) async {
    if (!isSupported) {
      debugPrint("Offline local database cache skipped: platform not supported.");
      return -1;
    }
    final db = await database;
    if (db == null) return -1;
    return await db.insert('offline_kots', {
      'table_id': kotData['table_id'],
      'service_type': kotData['service_type'] ?? 'Dine In',
      'waiter_id': kotData['waiter_id'],
      'captain_id': kotData['captain_id'],
      'remarks': kotData['remarks'] ?? '',
      'items': jsonEncode(kotData['items']),
      'status': 'pending',
    });
  }

  /// FETCH UNSYNCED KOTS
  Future<List<Map<String, dynamic>>> getPendingKots() async {
    if (!isSupported) return [];
    final db = await database;
    if (db == null) return [];
    final maps = await db.query(
      'offline_kots',
      where: 'status = ?',
      whereArgs: ['pending'],
    );
    return maps;
  }

  /// SYNC CACHED KOTS TO BACKEND
  Future<void> syncPendingKots() async {
    if (!isSupported) return;
    final pending = await getPendingKots();
    if (pending.isEmpty) return;

    for (final row in pending) {
      try {
        final payload = {
          'table_id': row['table_id'],
          'service_type': row['service_type'],
          'waiter_id': row['waiter_id'],
          'captain_id': row['captain_id'],
          'remarks': row['remarks'],
          'items': jsonDecode(row['items']),
        };

        // Post to API
        final res = await ApiClient.post(ApiEndpoints.restaurantKots, payload);
        if (res['success'] == true) {
          // Delete from local SQLite once successfully synced
          final db = await database;
          if (db != null) {
            await db.delete(
              'offline_kots',
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      } catch (e) {
        // Network might still be down, skip this and try next time
        break;
      }
    }
  }
}
