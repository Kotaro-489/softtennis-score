import '../models/match_models.dart';

class ScoreSnapshot {
  const ScoreSnapshot({
    required this.myGames,
    required this.opponentGames,
    required this.myPoints,
    required this.opponentPoints,
    required this.isFinalGame,
    required this.isCompleted,
    required this.servingSide,
    required this.serverId,
    required this.receiverId,
    required this.shouldChangeSides,
    required this.shouldChangeService,
    required this.gameWinners,
  });
  final int myGames;
  final int opponentGames;
  final int myPoints;
  final int opponentPoints;
  final bool isFinalGame;
  final bool isCompleted;
  final Side servingSide;
  final String serverId;
  final String receiverId;
  final bool shouldChangeSides;
  final bool shouldChangeService;
  final List<Side> gameWinners;
}

/// Flutterに依存しない得点・サービス順の状態遷移。
class ScoreRuleEngine {
  const ScoreRuleEngine();

  ScoreSnapshot evaluate(MatchRecord record) {
    var myGames = 0;
    var opponentGames = 0;
    var myPoints = 0;
    var opponentPoints = 0;
    var pointsInGame = 0;
    var completed = false;
    var changedSides = false;
    var changedService = false;
    final gameWinners = <Side>[];

    for (final event in record.events) {
      if (completed) break;
      changedSides = false;
      changedService = false;
      pointsInGame++;
      if (event.winningSide == Side.mine) {
        myPoints++;
      } else {
        opponentPoints++;
      }
      final finalGame = _isFinal(record.format, myGames, opponentGames);
      if (_winsGame(record.format, myPoints, opponentPoints, finalGame)) {
        final winner = myPoints > opponentPoints ? Side.mine : Side.opponent;
        if (winner == Side.mine) {
          myGames++;
        } else {
          opponentGames++;
        }
        gameWinners.add(winner);
        changedSides = !finalGame && (myGames + opponentGames).isOdd;
        changedService = true;
        completed =
            myGames == record.format.gamesToWin ||
            opponentGames == record.format.gamesToWin;
        if (!completed) {
          myPoints = 0;
          opponentPoints = 0;
          pointsInGame = 0;
        }
      }
      if (finalGame && !completed) {
        changedService = pointsInGame.isEven;
        changedSides =
            pointsInGame == 2 ||
            (pointsInGame > 2 && (pointsInGame - 2) % 4 == 0);
      }
    }

    final finalGame = _isFinal(record.format, myGames, opponentGames);
    final service = _service(
      record,
      myGames + opponentGames,
      pointsInGame,
      finalGame,
    );
    return ScoreSnapshot(
      myGames: myGames,
      opponentGames: opponentGames,
      myPoints: myPoints,
      opponentPoints: opponentPoints,
      isFinalGame: finalGame,
      isCompleted: completed,
      servingSide: service.$1,
      serverId: service.$2,
      receiverId: service.$3,
      shouldChangeSides: changedSides,
      shouldChangeService: changedService,
      gameWinners: List.unmodifiable(gameWinners),
    );
  }

  bool _isFinal(MatchFormatPreset format, int mine, int opponent) =>
      mine == format.maximumGames ~/ 2 && opponent == format.maximumGames ~/ 2;

  bool _winsGame(
    MatchFormatPreset format,
    int mine,
    int opponent,
    bool finalGame,
  ) {
    final target = finalGame ? 7 : 4;
    final noAd = format.isNoAd;
    final high = mine > opponent ? mine : opponent;
    return high >= target && (noAd || (mine - opponent).abs() >= 2);
  }

  (Side, String, String) _service(
    MatchRecord record,
    int completedGames,
    int pointIndex,
    bool finalGame,
  ) {
    final serviceBlock = pointIndex ~/ 2;
    final servingSide = finalGame
        ? serviceBlock.isEven
              ? record.firstServingSide
              : record.firstServingSide.other
        : completedGames.isEven
        ? record.firstServingSide
        : record.firstServingSide.other;
    final servingPair = servingSide == Side.mine
        ? record.myPair
        : record.opponentPair;
    final receivingPair = servingSide == Side.mine
        ? record.opponentPair
        : record.myPair;
    final initialServer = servingSide == record.firstServingSide
        ? record.firstServerId
        : record.firstReceiverId;
    final initialReceiver = servingSide == record.firstServingSide
        ? record.firstReceiverId
        : record.firstServerId;
    final serverRotation = finalGame ? serviceBlock ~/ 2 : pointIndex ~/ 2;
    final server = _alternatePlayer(servingPair, initialServer, serverRotation);
    final receiver = _alternatePlayer(
      receivingPair,
      initialReceiver,
      pointIndex,
    );
    return (servingSide, server, receiver);
  }

  String _alternatePlayer(Pair pair, String preferredId, int index) {
    final preferredIndex = pair.players.indexWhere(
      (player) => player.id == preferredId,
    );
    final base = preferredIndex < 0 ? 0 : preferredIndex;
    return pair.players[(base + index) % pair.players.length].id;
  }
}
