import 'package:flutter_test/flutter_test.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/services/match_analytics.dart';
import 'package:softtennis_score/services/score_rule_engine.dart';

void main() {
  test('勝率・取得率・連続得点・理由・未分類を集計する', () {
    final now = DateTime(2026);
    final record = MatchRecord(
      id: 'match',
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
      format: MatchFormatPreset.practiceThree,
      firstServingSide: Side.mine,
      firstServerId: 'm1',
      firstReceiverId: 'o1',
      createdAt: now,
      completedAt: now,
      events: [
        for (var index = 0; index < 8; index++)
          PointEvent(
            id: '$index',
            winningSide: Side.mine,
            reason: index == 0 ? PointReason.serviceAce : null,
            createdAt: now,
          ),
      ],
    );
    final result = MatchAnalytics.calculate([record], const ScoreRuleEngine());

    expect(result.winRate, 100);
    expect(result.gameRate, 1);
    expect(result.pointRate, 1);
    expect(result.longestScoringRun, 8);
    expect(result.myReasons[PointReason.serviceAce], 1);
    expect(result.unclassifiedPoints, 7);
  });
}
