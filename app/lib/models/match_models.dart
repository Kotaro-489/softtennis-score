enum Side { mine, opponent }

extension SideX on Side {
  Side get other => this == Side.mine ? Side.opponent : Side.mine;
  String get label => this == Side.mine ? '自分' : '相手';
}

enum MatchFormatPreset {
  officialFive,
  officialSeven,
  generalNine,
  practiceThree,
}

extension MatchFormatPresetX on MatchFormatPreset {
  int get maximumGames => switch (this) {
    MatchFormatPreset.officialFive => 5,
    MatchFormatPreset.officialSeven => 7,
    MatchFormatPreset.generalNine => 9,
    MatchFormatPreset.practiceThree => 3,
  };
  int get gamesToWin => (maximumGames ~/ 2) + 1;
  bool get isNoAd => this == MatchFormatPreset.practiceThree;
  bool get isOfficial => this != MatchFormatPreset.practiceThree;
  String get label => switch (this) {
    MatchFormatPreset.officialFive => '5ゲーム（公式）',
    MatchFormatPreset.officialSeven => '7ゲーム（公式）',
    MatchFormatPreset.generalNine => '9ゲーム（一般）',
    MatchFormatPreset.practiceThree => '3ゲーム（練習）',
  };
}

enum PointReason {
  serviceAce,
  returnAce,
  rallyWinner,
  opponentNet,
  opponentOut,
  opponentDoubleFault,
  other,
}

extension PointReasonX on PointReason {
  String get label => switch (this) {
    PointReason.serviceAce => 'サービスエース',
    PointReason.returnAce => 'リターンエース',
    PointReason.rallyWinner => 'ラリーウィナー',
    PointReason.opponentNet => '相手のネット',
    PointReason.opponentOut => '相手のアウト',
    PointReason.opponentDoubleFault => '相手のダブルフォルト',
    PointReason.other => 'その他',
  };
}

enum MatchStatus { inProgress, completed }

class Player {
  const Player({required this.id, required this.name});
  final String id;
  final String name;
}

class Pair {
  const Pair({required this.id, required this.name, required this.players});
  final String id;
  final String name;
  final List<Player> players;
}

class PointEvent {
  const PointEvent({
    required this.id,
    required this.winningSide,
    required this.createdAt,
    this.reason,
  });
  final String id;
  final Side winningSide;
  final DateTime createdAt;
  final PointReason? reason;
}

class MatchRecord {
  const MatchRecord({
    required this.id,
    required this.myPair,
    required this.opponentPair,
    required this.format,
    required this.firstServingSide,
    required this.firstServerId,
    required this.firstReceiverId,
    required this.createdAt,
    this.completedAt,
    this.events = const [],
  });
  final String id;
  final Pair myPair;
  final Pair opponentPair;
  final MatchFormatPreset format;
  final Side firstServingSide;
  final String firstServerId;
  final String firstReceiverId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final List<PointEvent> events;

  MatchRecord copyWith({
    List<PointEvent>? events,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) => MatchRecord(
    id: id,
    myPair: myPair,
    opponentPair: opponentPair,
    format: format,
    firstServingSide: firstServingSide,
    firstServerId: firstServerId,
    firstReceiverId: firstReceiverId,
    createdAt: createdAt,
    completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
    events: events ?? this.events,
  );
}

class MyPairProfile {
  const MyPairProfile({
    required this.pairName,
    required this.firstPlayerName,
    required this.secondPlayerName,
  });
  final String pairName;
  final String firstPlayerName;
  final String secondPlayerName;
}
