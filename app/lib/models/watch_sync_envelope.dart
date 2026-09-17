import 'match_record_codec.dart';
import 'match_models.dart';

enum WatchSyncMessageType { handoff, snapshot, requestPhoneControl, ack }

class WatchSyncEnvelope {
  const WatchSyncEnvelope({
    required this.schemaVersion,
    required this.messageId,
    required this.type,
    required this.matchId,
    required this.watchSessionId,
    required this.revision,
    required this.sentAt,
    this.match,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String messageId;
  final WatchSyncMessageType type;
  final String matchId;
  final String watchSessionId;
  final int revision;
  final DateTime sentAt;
  final MatchRecord? match;

  Map<String, dynamic> toMap({
    MatchRecordCodec codec = const MatchRecordCodec(),
  }) => {
    'schemaVersion': schemaVersion,
    'messageId': messageId,
    'type': type.name,
    'matchId': matchId,
    'watchSessionId': watchSessionId,
    'revision': revision,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'match': match == null ? null : codec.toMap(match!),
  };

  factory WatchSyncEnvelope.fromMap(
    Map<String, dynamic> map, {
    MatchRecordCodec codec = const MatchRecordCodec(),
  }) => WatchSyncEnvelope(
    schemaVersion: (map['schemaVersion'] as num).toInt(),
    messageId: map['messageId'] as String,
    type: WatchSyncMessageType.values.byName(map['type'] as String),
    matchId: map['matchId'] as String,
    watchSessionId: map['watchSessionId'] as String,
    revision: (map['revision'] as num).toInt(),
    sentAt: DateTime.parse(map['sentAt'] as String),
    match: map['match'] == null
        ? null
        : codec.fromMap(Map<String, dynamic>.from(map['match'] as Map)),
  );
}
