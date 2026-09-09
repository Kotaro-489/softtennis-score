import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/repositories/match_repository.dart';
import 'package:softtennis_score/services/score_rule_engine.dart';
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
}
