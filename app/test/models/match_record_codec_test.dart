import 'package:flutter_test/flutter_test.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/models/match_record_codec.dart';
import 'package:softtennis_score/models/watch_sync_envelope.dart';

void main() {
  MatchRecord record() => MatchRecord(
    id: 'match-1',
    myPair: const Pair(
      id: 'mine',
      name: '自分',
      players: [
        Player(id: 'm1', name: 'A'),
        Player(id: 'm2', name: 'B'),
      ],
    ),
    opponentPair: const Pair(
      id: 'opponent',
      name: '相手',
      players: [
        Player(id: 'o1', name: 'C'),
        Player(id: 'o2', name: 'D'),
      ],
    ),
    format: MatchFormatPreset.officialSeven,
    deuceEnabled: false,
    firstServingSide: Side.mine,
    firstServerId: 'm1',
    firstReceiverId: 'o1',
    createdAt: DateTime.utc(2026),
    currentServeAttempt: ServeAttempt.second,
    scoreInputOwner: ScoreInputOwner.watch,
    revision: 4,
    watchSessionId: 'watch-1',
  );

  test('MatchRecordを共通JSONで往復できる', () {
    const codec = MatchRecordCodec();
    final restored = codec.decode(codec.encode(record()));

    expect(restored.id, 'match-1');
    expect(restored.deuceEnabled, isFalse);
    expect(restored.currentServeAttempt, ServeAttempt.second);
    expect(restored.scoreInputOwner, ScoreInputOwner.watch);
    expect(restored.revision, 4);
    expect(restored.watchSessionId, 'watch-1');
  });

  test('旧JSONはゲーム形式ごとの従来値でデュース設定を復元する', () {
    const codec = MatchRecordCodec();
    final official = codec.toMap(record())..remove('deuceEnabled');
    expect(codec.fromMap(official).deuceEnabled, isTrue);

    final practice = codec.toMap(record())
      ..['format'] = MatchFormatPreset.practiceThree.name
      ..remove('deuceEnabled');
    expect(codec.fromMap(practice).deuceEnabled, isFalse);
  });

  test('同期Envelopeを共通Mapで往復できる', () {
    final envelope = WatchSyncEnvelope(
      schemaVersion: WatchSyncEnvelope.currentSchemaVersion,
      messageId: 'message-1',
      type: WatchSyncMessageType.snapshot,
      matchId: 'match-1',
      watchSessionId: 'watch-1',
      revision: 4,
      sentAt: DateTime.utc(2026),
      match: record(),
    );

    final restored = WatchSyncEnvelope.fromMap(envelope.toMap());
    expect(restored.schemaVersion, 2);
    expect(restored.messageId, 'message-1');
    expect(restored.match!.revision, 4);
    expect(restored.match!.deuceEnabled, isFalse);
    expect(restored.sentAt, DateTime.utc(2026));
  });
}
