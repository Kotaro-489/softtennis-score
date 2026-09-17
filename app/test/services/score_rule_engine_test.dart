import 'package:flutter_test/flutter_test.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/services/score_rule_engine.dart';

void main() {
  const engine = ScoreRuleEngine();

  MatchRecord record(
    MatchFormatPreset format,
    List<Side> winners, {
    bool? deuceEnabled,
  }) {
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
      deuceEnabled: deuceEnabled ?? format.defaultDeuceEnabled,
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

    test('全形式でデュース有無に応じて通常ゲームの決着条件が変わる', () {
      const threeAllThenMine = [
        Side.mine,
        Side.mine,
        Side.mine,
        Side.opponent,
        Side.opponent,
        Side.opponent,
        Side.mine,
      ];
      for (final format in MatchFormatPreset.values) {
        final deuce = engine.evaluate(
          record(format, threeAllThenMine, deuceEnabled: true),
        );
        expect(deuce.myGames, 0, reason: format.name);
        expect(deuce.myPoints, 4, reason: format.name);
        expect(deuce.opponentPoints, 3, reason: format.name);

        final noDeuce = engine.evaluate(
          record(format, threeAllThenMine, deuceEnabled: false),
        );
        expect(noDeuce.myGames, 1, reason: format.name);
        expect(noDeuce.myPoints, 0, reason: format.name);
      }
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

    test('全形式でデュース有無に応じてファイナルゲームの決着条件が変わる', () {
      final sixAll = <Side>[];
      for (var index = 0; index < 6; index++) {
        sixAll.addAll([Side.mine, Side.opponent]);
      }
      for (final format in MatchFormatPreset.values) {
        final tiedGames = <Side>[];
        for (var index = 0; index < format.maximumGames ~/ 2; index++) {
          tiedGames
            ..addAll(List.filled(4, Side.mine))
            ..addAll(List.filled(4, Side.opponent));
        }
        final advantage = [...tiedGames, ...sixAll, Side.mine];
        final deuce = engine.evaluate(
          record(format, advantage, deuceEnabled: true),
        );
        expect(deuce.isCompleted, isFalse, reason: format.name);
        expect(deuce.myPoints, 7, reason: format.name);
        expect(deuce.opponentPoints, 6, reason: format.name);

        final noDeuce = engine.evaluate(
          record(format, advantage, deuceEnabled: false),
        );
        expect(noDeuce.isCompleted, isTrue, reason: format.name);
        expect(noDeuce.myGames, format.gamesToWin, reason: format.name);

        final completedDeuce = engine.evaluate(
          record(format, [...advantage, Side.mine], deuceEnabled: true),
        );
        expect(completedDeuce.isCompleted, isTrue, reason: format.name);
      }
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

    test('ポイント時点のサービス側とサービス回数を復元する', () {
      final base = record(MatchFormatPreset.officialFive, [Side.opponent]);
      final point = base.events.single;
      final withSecondServe = base.copyWith(
        events: [
          PointEvent(
            id: point.id,
            winningSide: point.winningSide,
            createdAt: point.createdAt,
            serveAttempt: ServeAttempt.second,
          ),
        ],
      );

      final context = engine.contextForPoint(withSecondServe, point.id);
      expect(context!.servingSide, Side.mine);
      expect(context.winningSide, Side.opponent);
      expect(context.serveAttempt, ServeAttempt.second);
    });
  });
}
