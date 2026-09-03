import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/repositories/sqlite_match_repository.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  MatchRecord record({DateTime? completedAt}) => MatchRecord(
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
    completedAt: completedAt,
    events: [
      PointEvent(
        id: 'point-1',
        winningSide: Side.mine,
        reason: PointReason.serviceAce,
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

    await repository.save(record());
    final restored = await repository.findInProgress();
    expect(restored!.events.single.reason, PointReason.serviceAce);

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
}
