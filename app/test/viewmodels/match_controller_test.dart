import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/models/watch_sync_envelope.dart';
import 'package:softtennis_score/repositories/match_repository.dart';
import 'package:softtennis_score/services/score_rule_engine.dart';
import 'package:softtennis_score/services/watch_session_gateway.dart';
import 'package:softtennis_score/viewmodels/match_controller.dart';

class MemoryMatchRepository implements MatchRepository {
  MatchRecord? record;

  @override
  Future<void> delete(String id) async => record = null;
  @override
  Future<List<MatchRecord>> findCompleted() async =>
      record?.completedAt == null ? [] : [record!];
  @override
  Future<MatchRecord?> findInProgress() async =>
      record?.completedAt == null ? record : null;
  @override
  Future<MyPairProfile?> loadMyPairProfile() async => null;
  @override
  Future<void> save(MatchRecord value) async => record = value;
  @override
  Future<void> saveMyPairProfile(MyPairProfile profile) async {}
}

class BlockingMatchRepository extends MemoryMatchRepository {
  Completer<void>? saveGate;

  @override
  Future<void> save(MatchRecord value) async {
    await saveGate?.future;
    await super.save(value);
  }
}

class FakeWatchSessionGateway implements WatchSessionGateway {
  final eventsController = StreamController<WatchGatewayEvent>.broadcast();
  var acceptHandoff = true;
  WatchSyncEnvelope? handedOff;
  WatchSyncEnvelope? phoneControlResponse;
  final acknowledged = <String>[];
  final acknowledgedTypes = <WatchSyncMessageType>[];

  @override
  Stream<WatchGatewayEvent> get events => eventsController.stream;
  @override
  Future<void> ackPersisted(WatchSyncEnvelope envelope) async {
    acknowledged.add(envelope.messageId);
    acknowledgedTypes.add(envelope.type);
  }

  @override
  Future<WatchSyncEnvelope?> drainPendingEnvelope() async => null;
  @override
  Future<void> forcePhoneControl(String staleWatchSessionId) async {}
  @override
  Future<WatchConnectionStatus> getStatus() async =>
      const WatchConnectionStatus(
        supported: true,
        paired: true,
        appInstalled: true,
        reachable: true,
      );
  @override
  Future<bool> handoffMatch(WatchSyncEnvelope envelope) async {
    handedOff = envelope;
    return acceptHandoff;
  }

  @override
  Future<WatchSyncEnvelope?> requestPhoneControl(String watchSessionId) async =>
      phoneControlResponse;
}

void main() {
  MatchRecord initialRecord() => MatchRecord(
    id: 'match',
    myPair: const Pair(
      id: 'mine',
      name: '自分',
      players: [
        Player(id: 'm1', name: '自分1'),
        Player(id: 'm2', name: '自分2'),
      ],
    ),
    opponentPair: const Pair(
      id: 'opponent',
      name: '相手',
      players: [
        Player(id: 'o1', name: '相手1'),
        Player(id: 'o2', name: '相手2'),
      ],
    ),
    format: MatchFormatPreset.officialFive,
    deuceEnabled: true,
    firstServingSide: Side.mine,
    firstServerId: 'm1',
    firstReceiverId: 'o1',
    createdAt: DateTime(2026),
  );

  test('得点は保存され、取消でイベント履歴を1件戻す', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(initialRecord());
    await controller.addPoint(Side.mine, reason: PointReason.rallyWinner);
    expect(repository.record!.events, hasLength(1));
    expect(repository.record!.events.single.reason, PointReason.rallyWinner);

    await controller.undo();
    expect(repository.record!.events, isEmpty);
  });

  test('未完了試合は再読込みできる', () async {
    final repository = MemoryMatchRepository();
    final first = MatchController(repository, const ScoreRuleEngine());
    await first.start(initialRecord());
    await first.addPoint(Side.opponent);

    final restored = MatchController(repository, const ScoreRuleEngine());
    await restored.load();
    expect(restored.state.valueOrNull!.events, hasLength(1));
  });

  test('イベントIDを指定して得点理由を更新する', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(initialRecord());
    final firstId = await controller.addPoint(Side.mine);
    await controller.addPoint(Side.opponent);
    await controller.setPointReason(firstId!, PointReason.serviceAce);

    expect(repository.record!.events.first.reason, PointReason.serviceAce);
    expect(repository.record!.events.last.reason, isNull);
  });

  test('1stフォルトは2ndへ進み、次の通常得点にサービス回数を保存する', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(initialRecord());

    final outcome = await controller.recordFault();
    expect(outcome, ServeFaultOutcome.advancedToSecond);
    expect(repository.record!.events, isEmpty);
    expect(repository.record!.currentServeAttempt, ServeAttempt.second);

    await controller.addPoint(Side.mine);
    expect(repository.record!.events.single.serveAttempt, ServeAttempt.second);
    expect(repository.record!.currentServeAttempt, ServeAttempt.first);
  });

  test('2ndフォルトはレシーブ側へ得点とダブルフォルト理由を保存する', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(initialRecord());

    await controller.recordFault();
    final outcome = await controller.recordFault();

    expect(outcome, ServeFaultOutcome.doubleFaultRecorded);
    final event = repository.record!.events.single;
    expect(event.winningSide, Side.opponent);
    expect(event.reason, PointReason.opponentDoubleFault);
    expect(event.serveAttempt, ServeAttempt.second);
    expect(repository.record!.currentServeAttempt, ServeAttempt.first);
  });

  test('2ndで終了したポイントを取り消すと2ndへ戻り、再取消で1stへ戻る', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(initialRecord());
    await controller.recordFault();
    await controller.addPoint(Side.mine);

    await controller.undo();
    expect(repository.record!.events, isEmpty);
    expect(repository.record!.currentServeAttempt, ServeAttempt.second);

    await controller.undo();
    expect(repository.record!.events, isEmpty);
    expect(repository.record!.currentServeAttempt, ServeAttempt.first);
  });

  test('サービス状況と矛盾する得点理由は保存しない', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(initialRecord());

    expect(
      await controller.addPoint(Side.mine, reason: PointReason.returnAce),
      isNull,
    );
    expect(repository.record!.events, isEmpty);

    final eventId = await controller.addPoint(Side.mine);
    await controller.setPointReason(eventId!, PointReason.opponentDoubleFault);
    expect(repository.record!.events.single.reason, isNull);
  });

  test('保存中のフォルト二重入力を無視する', () async {
    final repository = BlockingMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(initialRecord());
    repository.saveGate = Completer<void>();

    final first = controller.recordFault();
    expect(await controller.recordFault(), isNull);
    repository.saveGate!.complete();

    expect(await first, ServeFaultOutcome.advancedToSecond);
    expect(repository.record!.events, isEmpty);
    expect(repository.record!.currentServeAttempt, ServeAttempt.second);
  });

  test('得点・フォルト・理由・取消ごとにrevisionを増やす', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(initialRecord());

    await controller.recordFault();
    expect(repository.record!.revision, 1);
    final eventID = await controller.addPoint(Side.mine);
    expect(repository.record!.revision, 2);
    await controller.setPointReason(eventID!, PointReason.serviceAce);
    expect(repository.record!.revision, 3);
    await controller.undo();
    expect(repository.record!.revision, 4);
  });

  test('Watch保存成功後だけ編集権をWatchへ移す', () async {
    final repository = MemoryMatchRepository();
    final gateway = FakeWatchSessionGateway();
    final controller = MatchController(
      repository,
      const ScoreRuleEngine(),
      watchGateway: gateway,
    );
    await controller.start(initialRecord());

    expect(await controller.handoffToWatch(), isTrue);
    expect(repository.record!.scoreInputOwner, ScoreInputOwner.watch);
    expect(repository.record!.revision, 1);
    expect(gateway.handedOff!.schemaVersion, 2);
    expect(gateway.handedOff!.match!.deuceEnabled, isTrue);
    expect(gateway.handedOff!.watchSessionId, isNotEmpty);
    expect(await controller.addPoint(Side.mine), isNull);
  });

  test('Watch引き渡し失敗時はiPhone編集を維持する', () async {
    final repository = MemoryMatchRepository();
    final gateway = FakeWatchSessionGateway()..acceptHandoff = false;
    final controller = MatchController(
      repository,
      const ScoreRuleEngine(),
      watchGateway: gateway,
    );
    await controller.start(initialRecord());

    expect(await controller.handoffToWatch(), isFalse);
    expect(repository.record!.scoreInputOwner, ScoreInputOwner.phone);
  });

  test('古いrevisionと異なるセッションを無視し、新しい状態だけ永続化する', () async {
    final repository = MemoryMatchRepository();
    final gateway = FakeWatchSessionGateway();
    final controller = MatchController(
      repository,
      const ScoreRuleEngine(),
      watchGateway: gateway,
    );
    await controller.start(initialRecord());
    await controller.handoffToWatch();
    final handedOff = repository.record!;

    WatchSyncEnvelope envelope(
      MatchRecord match,
      String messageId, {
      int schemaVersion = WatchSyncEnvelope.currentSchemaVersion,
    }) => WatchSyncEnvelope(
      schemaVersion: schemaVersion,
      messageId: messageId,
      type: WatchSyncMessageType.snapshot,
      matchId: match.id,
      watchSessionId: match.watchSessionId!,
      revision: match.revision,
      sentAt: DateTime(2026),
      match: match,
    );

    gateway.eventsController.add(envelope(handedOff, 'duplicate').asEvent());
    await Future<void>.delayed(Duration.zero);
    expect(gateway.acknowledged, isEmpty);

    final newer = handedOff.copyWith(revision: handedOff.revision + 1);
    gateway.eventsController.add(
      envelope(newer, 'legacy-schema', schemaVersion: 1).asEvent(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.record!.revision, handedOff.revision);
    expect(gateway.acknowledged, isEmpty);

    gateway.eventsController.add(WatchEnvelopeReceived(envelope(newer, 'new')));
    await Future<void>.delayed(Duration.zero);
    expect(repository.record!.revision, newer.revision);
    expect(gateway.acknowledged, ['new']);
  });

  test('同一revisionでも最新状態を確認してiPhoneへ編集権を戻せる', () async {
    final repository = MemoryMatchRepository();
    final gateway = FakeWatchSessionGateway();
    final controller = MatchController(
      repository,
      const ScoreRuleEngine(),
      watchGateway: gateway,
    );
    await controller.start(initialRecord());
    await controller.handoffToWatch();
    final watchRecord = repository.record!;
    gateway.phoneControlResponse = WatchSyncEnvelope(
      schemaVersion: WatchSyncEnvelope.currentSchemaVersion,
      messageId: 'return-control',
      type: WatchSyncMessageType.snapshot,
      matchId: watchRecord.id,
      watchSessionId: watchRecord.watchSessionId!,
      revision: watchRecord.revision,
      sentAt: DateTime(2026),
      match: watchRecord,
    );

    expect(await controller.requestPhoneControl(), isTrue);
    expect(repository.record!.scoreInputOwner, ScoreInputOwner.phone);
    expect(repository.record!.watchSessionId, isNull);
    expect(
      gateway.acknowledgedTypes,
      contains(WatchSyncMessageType.requestPhoneControl),
    );
  });
}

extension on WatchSyncEnvelope {
  WatchGatewayEvent asEvent() => WatchEnvelopeReceived(this);
}
