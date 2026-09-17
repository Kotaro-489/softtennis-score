import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/services/score_rule_engine.dart';

void main() {
  test('Swiftと共有するJSONルールベクトルに一致する', () {
    final vectors = jsonDecode(
      File('ios/WatchShared/rule_vectors.json').readAsStringSync(),
    ) as List<dynamic>;

    for (final raw in vectors) {
      final vector = Map<String, dynamic>.from(raw as Map);
      final winners = (vector['winners'] as List<dynamic>)
          .map((value) => Side.values.byName(value as String))
          .toList();
      final record = _record(
        format: MatchFormatPreset.values.byName(vector['format'] as String),
        deuceEnabled: vector['deuceEnabled'] as bool,
        winners: winners,
      );
      final actual = const ScoreRuleEngine().evaluate(record);
      final expected = Map<String, dynamic>.from(vector['expected'] as Map);

      expect(
        actual.myGames,
        expected['myGames'],
        reason: vector['name'] as String,
      );
      expect(
        actual.opponentGames,
        expected['opponentGames'],
        reason: vector['name'] as String,
      );
      expect(
        actual.myPoints,
        expected['myPoints'],
        reason: vector['name'] as String,
      );
      expect(
        actual.opponentPoints,
        expected['opponentPoints'],
        reason: vector['name'] as String,
      );
      expect(
        actual.servingSide.name,
        expected['servingSide'],
        reason: vector['name'] as String,
      );
      expect(
        actual.serverId,
        expected['serverId'],
        reason: vector['name'] as String,
      );
      expect(
        actual.receiverId,
        expected['receiverId'],
        reason: vector['name'] as String,
      );
      expect(
        actual.shouldChangeSides,
        expected['shouldChangeSides'],
        reason: vector['name'] as String,
      );
      expect(
        actual.shouldChangeService,
        expected['shouldChangeService'],
        reason: vector['name'] as String,
      );
      expect(
        actual.isCompleted,
        expected['isCompleted'],
        reason: vector['name'] as String,
      );
    }
  });
}

MatchRecord _record({
  required MatchFormatPreset format,
  required bool deuceEnabled,
  required List<Side> winners,
}) => MatchRecord(
  id: 'vector',
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
  deuceEnabled: deuceEnabled,
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
