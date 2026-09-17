import 'dart:convert';

import 'match_models.dart';

/// SQLite、Platform Channel、watchOSで共有する試合JSONの唯一の定義。
class MatchRecordCodec {
  const MatchRecordCodec();

  String encode(MatchRecord record) => jsonEncode(toMap(record));

  MatchRecord decode(String source) =>
      fromMap(jsonDecode(source) as Map<String, dynamic>);

  Map<String, dynamic> toMap(MatchRecord record) => {
    'id': record.id,
    'myPair': _pairMap(record.myPair),
    'opponentPair': _pairMap(record.opponentPair),
    'format': record.format.name,
    'firstServingSide': record.firstServingSide.name,
    'firstServerId': record.firstServerId,
    'firstReceiverId': record.firstReceiverId,
    'currentServeAttempt': record.currentServeAttempt.name,
    'scoreInputOwner': record.scoreInputOwner.name,
    'revision': record.revision,
    'watchSessionId': record.watchSessionId,
    'createdAt': record.createdAt.toIso8601String(),
    'completedAt': record.completedAt?.toIso8601String(),
    'events': record.events
        .map(
          (event) => {
            'id': event.id,
            'winningSide': event.winningSide.name,
            'reason': event.reason?.name,
            'serveAttempt': event.serveAttempt.name,
            'createdAt': event.createdAt.toIso8601String(),
          },
        )
        .toList(),
  };

  MatchRecord fromMap(Map<String, dynamic> map) => MatchRecord(
    id: map['id'] as String,
    myPair: _pairFromMap(_stringMap(map['myPair'])),
    opponentPair: _pairFromMap(_stringMap(map['opponentPair'])),
    format: MatchFormatPreset.values.byName(map['format'] as String),
    firstServingSide: Side.values.byName(map['firstServingSide'] as String),
    firstServerId: map['firstServerId'] as String,
    firstReceiverId: map['firstReceiverId'] as String,
    currentServeAttempt: map['currentServeAttempt'] == null
        ? ServeAttempt.first
        : ServeAttempt.values.byName(map['currentServeAttempt'] as String),
    scoreInputOwner: map['scoreInputOwner'] == null
        ? ScoreInputOwner.phone
        : ScoreInputOwner.values.byName(map['scoreInputOwner'] as String),
    revision: (map['revision'] as num?)?.toInt() ?? 0,
    watchSessionId: map['watchSessionId'] as String?,
    createdAt: DateTime.parse(map['createdAt'] as String),
    completedAt: map['completedAt'] == null
        ? null
        : DateTime.parse(map['completedAt'] as String),
    events: (map['events'] as List<dynamic>).map((item) {
      final event = _stringMap(item);
      return PointEvent(
        id: event['id'] as String,
        winningSide: Side.values.byName(event['winningSide'] as String),
        reason: event['reason'] == null
            ? null
            : PointReason.values.byName(event['reason'] as String),
        serveAttempt: event['serveAttempt'] == null
            ? ServeAttempt.first
            : ServeAttempt.values.byName(event['serveAttempt'] as String),
        createdAt: DateTime.parse(event['createdAt'] as String),
      );
    }).toList(),
  );

  Map<String, dynamic> _pairMap(Pair pair) => {
    'id': pair.id,
    'name': pair.name,
    'players': pair.players
        .map((player) => {'id': player.id, 'name': player.name})
        .toList(),
  };

  Pair _pairFromMap(Map<String, dynamic> map) => Pair(
    id: map['id'] as String,
    name: map['name'] as String,
    players: (map['players'] as List<dynamic>).map((item) {
      final player = _stringMap(item);
      return Player(id: player['id'] as String, name: player['name'] as String);
    }).toList(),
  );

  Map<String, dynamic> _stringMap(Object? value) =>
      Map<String, dynamic>.from(value! as Map);
}
