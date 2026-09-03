import 'dart:convert';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/match_models.dart';
import 'match_repository.dart';

class SqliteMatchRepository implements MatchRepository {
  SqliteMatchRepository({DatabaseFactory? factory, this.databasePath})
    : _factory = factory ?? databaseFactory;

  final DatabaseFactory _factory;
  final String? databasePath;
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
      'payload': jsonEncode(_toMap(record)),
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
        : _fromMap(
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
          (row) => _fromMap(
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

  Map<String, dynamic> _toMap(MatchRecord record) => {
    'id': record.id,
    'myPair': _pairMap(record.myPair),
    'opponentPair': _pairMap(record.opponentPair),
    'format': record.format.name,
    'firstServingSide': record.firstServingSide.name,
    'firstServerId': record.firstServerId,
    'firstReceiverId': record.firstReceiverId,
    'createdAt': record.createdAt.toIso8601String(),
    'completedAt': record.completedAt?.toIso8601String(),
    'events': record.events
        .map(
          (event) => {
            'id': event.id,
            'winningSide': event.winningSide.name,
            'reason': event.reason?.name,
            'createdAt': event.createdAt.toIso8601String(),
          },
        )
        .toList(),
  };

  Map<String, dynamic> _pairMap(Pair pair) => {
    'id': pair.id,
    'name': pair.name,
    'players': pair.players
        .map((player) => {'id': player.id, 'name': player.name})
        .toList(),
  };

  MatchRecord _fromMap(Map<String, dynamic> map) => MatchRecord(
    id: map['id'] as String,
    myPair: _pairFromMap(map['myPair'] as Map<String, dynamic>),
    opponentPair: _pairFromMap(map['opponentPair'] as Map<String, dynamic>),
    format: MatchFormatPreset.values.byName(map['format'] as String),
    firstServingSide: Side.values.byName(map['firstServingSide'] as String),
    firstServerId: map['firstServerId'] as String,
    firstReceiverId: map['firstReceiverId'] as String,
    createdAt: DateTime.parse(map['createdAt'] as String),
    completedAt: map['completedAt'] == null
        ? null
        : DateTime.parse(map['completedAt'] as String),
    events: (map['events'] as List<dynamic>).map((item) {
      final event = item as Map<String, dynamic>;
      return PointEvent(
        id: event['id'] as String,
        winningSide: Side.values.byName(event['winningSide'] as String),
        reason: event['reason'] == null
            ? null
            : PointReason.values.byName(event['reason'] as String),
        createdAt: DateTime.parse(event['createdAt'] as String),
      );
    }).toList(),
  );

  Pair _pairFromMap(Map<String, dynamic> map) => Pair(
    id: map['id'] as String,
    name: map['name'] as String,
    players: (map['players'] as List<dynamic>).map((item) {
      final player = item as Map<String, dynamic>;
      return Player(id: player['id'] as String, name: player['name'] as String);
    }).toList(),
  );
}
