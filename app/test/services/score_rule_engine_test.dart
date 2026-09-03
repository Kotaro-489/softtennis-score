import 'package:flutter_test/flutter_test.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/services/score_rule_engine.dart';

void main() {
  const engine = ScoreRuleEngine();

  MatchRecord record(MatchFormatPreset format, List<Side> winners) {
    final now = DateTime(2026);
    return MatchRecord(
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
      format: format,
      firstServingSide: Side.mine,
      firstServerId: 'm1',
      firstReceiverId: 'o1',
      createdAt: now,
      events: [
        for (var index = 0; index < winners.length; index++)
          PointEvent(id: '$index', winningSide: winners[index], createdAt: now),
      ],
    );
  }

  group('ScoreRuleEngine', () {
    test('通常ゲームは4ポイント先取', () {
      final score = engine.evaluate(
        record(MatchFormatPreset.officialFive, List.filled(4, Side.mine)),
      );
      expect(score.myGames, 1);
      expect(score.myPoints, 0);
    });

    test('デュースは2ポイント差が必要', () {
      final score = engine.evaluate(
        record(MatchFormatPreset.officialFive, [
          Side.mine,
          Side.mine,
          Side.mine,
          Side.opponent,
          Side.opponent,
          Side.opponent,
          Side.mine,
          Side.opponent,
          Side.mine,
          Side.mine,
        ]),
      );
      expect(score.myGames, 1);
    });

    test('練習3ゲームはノーアドで4ポイント目が決着', () {
      final score = engine.evaluate(
        record(MatchFormatPreset.practiceThree, [
          Side.mine,
          Side.mine,
          Side.mine,
          Side.opponent,
          Side.opponent,
          Side.opponent,
          Side.opponent,
        ]),
      );
      expect(score.opponentGames, 1);
    });

    test('5ゲームの同点最終ゲームは7ポイント先取', () {
      final winners = [
        ...List.filled(4, Side.mine),
        ...List.filled(4, Side.opponent),
        ...List.filled(4, Side.mine),
        ...List.filled(4, Side.opponent),
        ...List.filled(7, Side.mine),
      ];
      final score = engine.evaluate(
        record(MatchFormatPreset.officialFive, winners),
      );
      expect(score.isCompleted, isTrue);
      expect(score.myGames, 3);
      expect(score.opponentGames, 2);
    });

    test('9ゲームは5ゲーム先取', () {
      final winners = <Side>[];
      for (var game = 0; game < 5; game++) {
        winners.addAll(List.filled(4, Side.mine));
      }
      final score = engine.evaluate(
        record(MatchFormatPreset.generalNine, winners),
      );
      expect(score.isCompleted, isTrue);
      expect(score.myGames, 5);
    });

    test('通常ゲームのサービスは2ポイントごとにペア内で交代', () {
      final initial = engine.evaluate(
        record(MatchFormatPreset.officialSeven, []),
      );
      final afterTwo = engine.evaluate(
        record(MatchFormatPreset.officialSeven, [Side.mine, Side.opponent]),
      );
      expect(initial.serverId, 'm1');
      expect(afterTwo.serverId, 'm2');
    });

    test('7ゲームと9ゲームはそれぞれ4・5ゲーム先取', () {
      for (final testCase in [
        (MatchFormatPreset.officialSeven, 4),
        (MatchFormatPreset.generalNine, 5),
      ]) {
        final score = engine.evaluate(
          record(testCase.$1, List.filled(testCase.$2 * 4, Side.mine)),
        );
        expect(score.isCompleted, isTrue);
        expect(score.myGames, testCase.$2);
      }
    });

    test('ファイナルゲームは6-6から2ポイント差を必要とする', () {
      final tiedGames = [
        ...List.filled(4, Side.mine),
        ...List.filled(4, Side.opponent),
        ...List.filled(4, Side.mine),
        ...List.filled(4, Side.opponent),
      ];
      final sixAll = <Side>[];
      for (var index = 0; index < 6; index++) {
        sixAll.addAll([Side.mine, Side.opponent]);
      }
      final advantage = engine.evaluate(
        record(MatchFormatPreset.officialFive, [
          ...tiedGames,
          ...sixAll,
          Side.mine,
        ]),
      );
      expect(advantage.isCompleted, isFalse);
      final completed = engine.evaluate(
        record(MatchFormatPreset.officialFive, [
          ...tiedGames,
          ...sixAll,
          Side.mine,
          Side.mine,
        ]),
      );
      expect(completed.isCompleted, isTrue);
    });

    test('ファイナルゲームは2ポイントごとに両ペアの選手が順番にサービスする', () {
      final tiedGames = [
        ...List.filled(4, Side.mine),
        ...List.filled(4, Side.opponent),
        ...List.filled(4, Side.mine),
        ...List.filled(4, Side.opponent),
      ];
      ScoreSnapshot after(int points) => engine.evaluate(
        record(MatchFormatPreset.officialFive, [
          ...tiedGames,
          ...List.filled(points, Side.mine),
        ]),
      );
      expect(after(0).serverId, 'm1');
      expect(after(2).serverId, 'o1');
      expect(after(4).serverId, 'm2');
      expect(after(6).serverId, 'o2');
      expect(after(2).shouldChangeSides, isTrue);
      expect(after(6).shouldChangeSides, isTrue);
    });

    test('通常ゲーム後の案内は次ポイントで解除される', () {
      final gameEnd = engine.evaluate(
        record(MatchFormatPreset.officialSeven, List.filled(4, Side.mine)),
      );
      expect(gameEnd.shouldChangeSides, isTrue);
      expect(gameEnd.shouldChangeService, isTrue);
      final nextPoint = engine.evaluate(
        record(MatchFormatPreset.officialSeven, [
          ...List.filled(4, Side.mine),
          Side.opponent,
        ]),
      );
      expect(nextPoint.shouldChangeSides, isFalse);
      expect(nextPoint.shouldChangeService, isFalse);
    });
  });
}
