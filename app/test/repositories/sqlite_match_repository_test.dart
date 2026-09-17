import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/repositories/sqlite_match_repository.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  MatchRecord record({
    DateTime? completedAt,
    ServeAttempt currentServeAttempt = ServeAttempt.first,
    ServeAttempt pointServeAttempt = ServeAttempt.first,
    ScoreInputOwner scoreInputOwner = ScoreInputOwner.phone,
    int revision = 0,
    String? watchSessionId,
  }) => MatchRecord(
    id: 'match-1',
    myPair: const Pair(
      id: 'mine',
      name: '自分ペア',
      players: [
        Player(id: 'm1', name: 'A'),
        Player(id: 'm2', name: 'B'),
      ],
    ),
    opponentPair: const Pair(
      id: 'opponent',
      name: '相手ペア',
      players: [
        Player(id: 'o1', name: 'C'),
        Player(id: 'o2', name: 'D'),
      ],
    ),
    format: MatchFormatPreset.officialFive,
    firstServingSide: Side.mine,
    firstServerId: 'm1',
    firstReceiverId: 'o1',
    createdAt: DateTime(2026),
    currentServeAttempt: currentServeAttempt,
    scoreInputOwner: scoreInputOwner,
    revision: revision,
    watchSessionId: watchSessionId,
    completedAt: completedAt,
    events: [
      PointEvent(
        id: 'point-1',
        winningSide: Side.mine,
        reason: PointReason.serviceAce,
        serveAttempt: pointServeAttempt,
        createdAt: DateTime(2026),
      ),
    ],
  );

  test('SQLiteで保存・復元・完了一覧・削除ができる', () async {
    final directory = await Directory.systemTemp.createTemp(
      'softtennis-score-',
    );
    final path = '${directory.path}/test.db';
    final repository = SqliteMatchRepository(
      factory: factory,
      databasePath: path,
    );
    addTearDown(() async {
      await repository.close();
      await directory.delete(recursive: true);
    });

    await repository.save(
      record(
        currentServeAttempt: ServeAttempt.second,
        pointServeAttempt: ServeAttempt.second,
        scoreInputOwner: ScoreInputOwner.watch,
        revision: 7,
        watchSessionId: 'session-1',
      ),
    );
    final restored = await repository.findInProgress();
    expect(restored!.events.single.reason, PointReason.serviceAce);
    expect(restored.currentServeAttempt, ServeAttempt.second);
    expect(restored.events.single.serveAttempt, ServeAttempt.second);
    expect(restored.scoreInputOwner, ScoreInputOwner.watch);
    expect(restored.revision, 7);
    expect(restored.watchSessionId, 'session-1');

    await repository.save(record(completedAt: DateTime(2026, 1, 2)));
    expect(await repository.findInProgress(), isNull);
    expect(await repository.findCompleted(), hasLength(1));

    await repository.delete('match-1');
    expect(await repository.findCompleted(), isEmpty);
  });

  test('v1からv2へ移行し、自分ペア設定を保存できる', () async {
    final directory = await Directory.systemTemp.createTemp(
      'softtennis-migration-',
    );
    final path = '${directory.path}/test.db';
    final oldDatabase = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE matches (id TEXT PRIMARY KEY, completedAt TEXT, createdAt TEXT NOT NULL, payload TEXT NOT NULL)',
          );
        },
      ),
    );
    await oldDatabase.close();
    final repository = SqliteMatchRepository(
      factory: factory,
      databasePath: path,
    );
    addTearDown(() async {
      await repository.close();
      await directory.delete(recursive: true);
    });

    const profile = MyPairProfile(
      pairName: 'いつものペア',
      firstPlayerName: 'A',
      secondPlayerName: 'B',
    );
    await repository.saveMyPairProfile(profile);
    final restored = await repository.loadMyPairProfile();
    expect(restored!.pairName, 'いつものペア');
    expect(restored.secondPlayerName, 'B');
  });

  test('旧JSONにサービス回数がない場合は1stとして復元する', () async {
    final directory = await Directory.systemTemp.createTemp(
      'softtennis-legacy-payload-',
    );
    final path = '${directory.path}/test.db';
    final writer = SqliteMatchRepository(factory: factory, databasePath: path);
    await writer.save(record());
    await writer.close();

    final rawDatabase = await factory.openDatabase(path);
    final row = (await rawDatabase.query('matches')).single;
    final payload =
        jsonDecode(row['payload']! as String) as Map<String, dynamic>;
    payload.remove('currentServeAttempt');
    payload.remove('scoreInputOwner');
    payload.remove('revision');
    payload.remove('watchSessionId');
    for (final item in payload['events'] as List<dynamic>) {
      (item as Map<String, dynamic>).remove('serveAttempt');
    }
    await rawDatabase.update(
      'matches',
      {'payload': jsonEncode(payload)},
      where: 'id = ?',
      whereArgs: ['match-1'],
    );
    await rawDatabase.close();

    final reader = SqliteMatchRepository(factory: factory, databasePath: path);
    addTearDown(() async {
      await reader.close();
      await directory.delete(recursive: true);
    });

    final restored = await reader.findInProgress();
    expect(restored!.currentServeAttempt, ServeAttempt.first);
    expect(restored.events.single.serveAttempt, ServeAttempt.first);
    expect(restored.scoreInputOwner, ScoreInputOwner.phone);
    expect(restored.revision, 0);
    expect(restored.watchSessionId, isNull);
  });
}
