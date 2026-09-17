import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/match_models.dart';
import '../models/match_record_codec.dart';
import 'match_repository.dart';

class SqliteMatchRepository implements MatchRepository {
  SqliteMatchRepository({
    DatabaseFactory? factory,
    this.databasePath,
    this.codec = const MatchRecordCodec(),
  }) : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? databasePath;
  final MatchRecordCodec codec;
  Database? _database;

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }

  Future<Database> get _db async {
    if (_database != null) return _database!;
    final path =
        databasePath ??
        join(await _factory.getDatabasesPath(), 'softtennis_score.db');
    _database = await _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE matches (id TEXT PRIMARY KEY, completedAt TEXT, createdAt TEXT NOT NULL, payload TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE settings (key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
          );
        },
        onUpgrade: (db, oldVersion, _) async {
          if (oldVersion < 2) {
            await db.execute(
              'CREATE TABLE settings (key TEXT PRIMARY KEY, payload TEXT NOT NULL)',
            );
          }
        },
      ),
    );
    return _database!;
  }

  @override
  Future<void> save(MatchRecord record) async {
    final db = await _db;
    await db.insert('matches', {
      'id': record.id,
      'completedAt': record.completedAt?.toIso8601String(),
      'createdAt': record.createdAt.toIso8601String(),
      'payload': codec.encode(record),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<MatchRecord?> findInProgress() async {
    final db = await _db;
    final rows = await db.query(
      'matches',
      where: 'completedAt IS NULL',
      orderBy: 'createdAt DESC',
      limit: 1,
    );
    return rows.isEmpty
        ? null
        : codec.fromMap(
            jsonDecode(rows.first['payload']! as String)
                as Map<String, dynamic>,
          );
  }

  @override
  Future<List<MatchRecord>> findCompleted() async {
    final db = await _db;
    final rows = await db.query(
      'matches',
      where: 'completedAt IS NOT NULL',
      orderBy: 'completedAt DESC',
    );
    return rows
        .map(
          (row) => codec.fromMap(
            jsonDecode(row['payload']! as String) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  @override
  Future<void> delete(String id) async =>
      (await _db).delete('matches', where: 'id = ?', whereArgs: [id]);

  @override
  Future<MyPairProfile?> loadMyPairProfile() async {
    final rows = await (await _db).query(
      'settings',
      where: 'key = ?',
      whereArgs: ['myPair'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final map =
        jsonDecode(rows.single['payload']! as String) as Map<String, dynamic>;
    return MyPairProfile(
      pairName: map['pairName'] as String,
      firstPlayerName: map['firstPlayerName'] as String,
      secondPlayerName: map['secondPlayerName'] as String,
    );
  }

  @override
  Future<void> saveMyPairProfile(MyPairProfile profile) async {
    await (await _db).insert('settings', {
      'key': 'myPair',
      'payload': jsonEncode({
        'pairName': profile.pairName,
        'firstPlayerName': profile.firstPlayerName,
        'secondPlayerName': profile.secondPlayerName,
      }),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
