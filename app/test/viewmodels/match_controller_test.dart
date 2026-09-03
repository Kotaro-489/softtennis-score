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
}
