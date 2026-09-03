import '../models/match_models.dart';
import 'score_rule_engine.dart';

class MatchAnalytics {
  const MatchAnalytics({
    required this.matchCount,
    required this.wins,
    required this.gameRate,
    required this.pointRate,
    required this.longestScoringRun,
    required this.unclassifiedPoints,
    required this.myReasons,
    required this.opponentReasons,
  });

  final int matchCount;
  final int wins;
  final double gameRate;
  final double pointRate;
  final int longestScoringRun;
  final int unclassifiedPoints;
  final Map<PointReason, int> myReasons;
  final Map<PointReason, int> opponentReasons;

  int get winRate => matchCount == 0 ? 0 : (wins / matchCount * 100).round();

  factory MatchAnalytics.calculate(
    List<MatchRecord> records,
    ScoreRuleEngine engine,
  ) {
    var wins = 0;
    var myGames = 0;
    var allGames = 0;
    var myPoints = 0;
    var allPoints = 0;
    var longestRun = 0;
    var unclassified = 0;
    final myReasons = <PointReason, int>{};
    final opponentReasons = <PointReason, int>{};

    for (final record in records) {
      final score = engine.evaluate(record);
      if (score.myGames > score.opponentGames) wins++;
      myGames += score.myGames;
      allGames += score.myGames + score.opponentGames;
      var run = 0;
      for (final event in record.events) {
        allPoints++;
        if (event.winningSide == Side.mine) {
          myPoints++;
          run++;
          if (run > longestRun) longestRun = run;
        } else {
          run = 0;
        }
        if (event.reason == null) {
          unclassified++;
        } else {
          final target = event.winningSide == Side.mine
              ? myReasons
              : opponentReasons;
          target[event.reason!] = (target[event.reason!] ?? 0) + 1;
        }
      }
    }

    return MatchAnalytics(
      matchCount: records.length,
      wins: wins,
      gameRate: allGames == 0 ? 0 : myGames / allGames,
      pointRate: allPoints == 0 ? 0 : myPoints / allPoints,
      longestScoringRun: longestRun,
      unclassifiedPoints: unclassified,
      myReasons: myReasons,
      opponentReasons: opponentReasons,
    );
  }
}
