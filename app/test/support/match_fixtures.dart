import 'package:softtennis_score/models/match_models.dart';

/// 各テストで必要なルールとイベントだけを指定できる、共通のダブルス試合を作る。
MatchRecord matchRecord({
  String id = 'match',
  MatchFormatPreset format = MatchFormatPreset.officialFive,
  bool? deuceEnabled,
  List<Side> winners = const [],
}) => MatchRecord(
  id: id,
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
  format: format,
  deuceEnabled: deuceEnabled ?? format.defaultDeuceEnabled,
  firstServingSide: Side.mine,
  firstServerId: 'm1',
  firstReceiverId: 'o1',
  createdAt: DateTime.utc(2026),
  events: [
    for (var index = 0; index < winners.length; index++)
      PointEvent(
        id: '$index',
        winningSide: winners[index],
        createdAt: DateTime.utc(2026),
      ),
  ],
);
