import 'package:flutter_test/flutter_test.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/services/point_reason_policy.dart';

void main() {
  const policy = PointReasonPolicy();

  test('サービス側得点ではサービスエースだけをサービス関連理由に含める', () {
    final reasons = policy.availableReasons(
      servingSide: Side.mine,
      winningSide: Side.mine,
      serveAttempt: ServeAttempt.first,
    );

    expect(reasons, contains(PointReason.serviceAce));
    expect(reasons, isNot(contains(PointReason.returnAce)));
    expect(reasons, isNot(contains(PointReason.opponentDoubleFault)));
  });

  test('1stのレシーブ側得点ではリターンエースだけをサービス関連理由に含める', () {
    final reasons = policy.availableReasons(
      servingSide: Side.mine,
      winningSide: Side.opponent,
      serveAttempt: ServeAttempt.first,
    );

    expect(reasons, isNot(contains(PointReason.serviceAce)));
    expect(reasons, contains(PointReason.returnAce));
    expect(reasons, isNot(contains(PointReason.opponentDoubleFault)));
  });

  test('2ndのレシーブ側得点ではリターンエースとダブルフォルトを含める', () {
    final reasons = policy.availableReasons(
      servingSide: Side.mine,
      winningSide: Side.opponent,
      serveAttempt: ServeAttempt.second,
    );

    expect(reasons, isNot(contains(PointReason.serviceAce)));
    expect(reasons, contains(PointReason.returnAce));
    expect(reasons, contains(PointReason.opponentDoubleFault));
  });

  test('ラリー理由はサービス状況にかかわらず含める', () {
    final reasons = policy.availableReasons(
      servingSide: Side.opponent,
      winningSide: Side.mine,
      serveAttempt: ServeAttempt.second,
    );

    expect(
      reasons,
      containsAll([
        PointReason.rallyWinner,
        PointReason.opponentNet,
        PointReason.opponentOut,
        PointReason.other,
      ]),
    );
  });
}
