import 'dart:async';

import 'package:flutter/services.dart';

import '../models/watch_sync_envelope.dart';

class WatchConnectionStatus {
  const WatchConnectionStatus({
    required this.supported,
    required this.paired,
    required this.appInstalled,
    required this.reachable,
    this.lastSyncAt,
  });

  const WatchConnectionStatus.unsupported()
    : supported = false,
      paired = false,
      appInstalled = false,
      reachable = false,
      lastSyncAt = null;

  final bool supported;
  final bool paired;
  final bool appInstalled;
  final bool reachable;
  final DateTime? lastSyncAt;

  bool get canHandoff => supported && paired && appInstalled && reachable;

  factory WatchConnectionStatus.fromMap(Map<String, dynamic> map) =>
      WatchConnectionStatus(
        supported: map['supported'] as bool? ?? false,
        paired: map['paired'] as bool? ?? false,
        appInstalled: map['appInstalled'] as bool? ?? false,
        reachable: map['reachable'] as bool? ?? false,
        lastSyncAt: map['lastSyncAt'] == null
            ? null
            : DateTime.parse(map['lastSyncAt'] as String),
      );
}

sealed class WatchGatewayEvent {
  const WatchGatewayEvent();
}

class WatchStatusChanged extends WatchGatewayEvent {
  const WatchStatusChanged(this.status);
  final WatchConnectionStatus status;
}

class WatchEnvelopeReceived extends WatchGatewayEvent {
  const WatchEnvelopeReceived(this.envelope);
  final WatchSyncEnvelope envelope;
}

abstract interface class WatchSessionGateway {
  Stream<WatchGatewayEvent> get events;
  Future<WatchConnectionStatus> getStatus();
  Future<bool> handoffMatch(WatchSyncEnvelope envelope);
  Future<WatchSyncEnvelope?> requestPhoneControl(String watchSessionId);
  Future<void> forcePhoneControl(String staleWatchSessionId);
  Future<WatchSyncEnvelope?> drainPendingEnvelope();
  Future<void> ackPersisted(WatchSyncEnvelope envelope);
}

class NoopWatchSessionGateway implements WatchSessionGateway {
  const NoopWatchSessionGateway();

  @override
  Stream<WatchGatewayEvent> get events => const Stream.empty();

  @override
  Future<void> ackPersisted(WatchSyncEnvelope envelope) async {}

  @override
  Future<WatchSyncEnvelope?> drainPendingEnvelope() async => null;

  @override
  Future<void> forcePhoneControl(String staleWatchSessionId) async {}

  @override
  Future<WatchConnectionStatus> getStatus() async =>
      const WatchConnectionStatus.unsupported();

  @override
  Future<bool> handoffMatch(WatchSyncEnvelope envelope) async => false;

  @override
  Future<WatchSyncEnvelope?> requestPhoneControl(String watchSessionId) async =>
      null;
}

class MethodChannelWatchSessionGateway implements WatchSessionGateway {
  MethodChannelWatchSessionGateway({
    MethodChannel? methodChannel,
    EventChannel? eventChannel,
  }) : _methodChannel =
           methodChannel ??
           const MethodChannel('com.kotaro489.softtennisscore/watch'),
       _eventChannel =
           eventChannel ??
           const EventChannel('com.kotaro489.softtennisscore/watch/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  late final Stream<WatchGatewayEvent> _events = _eventChannel
      .receiveBroadcastStream()
      .map((value) => _eventFromMap(_map(value)))
      .asBroadcastStream();

  @override
  Stream<WatchGatewayEvent> get events => _events;

  @override
  Future<WatchConnectionStatus> getStatus() async =>
      WatchConnectionStatus.fromMap(
        _map(await _methodChannel.invokeMethod<Object?>('getStatus')),
      );

  @override
  Future<bool> handoffMatch(WatchSyncEnvelope envelope) async =>
      await _methodChannel.invokeMethod<bool>(
        'handoffMatch',
        envelope.toMap(),
      ) ??
      false;

  @override
  Future<WatchSyncEnvelope?> requestPhoneControl(String watchSessionId) async {
    final value = await _methodChannel.invokeMethod<Object?>(
      'requestPhoneControl',
      {'watchSessionId': watchSessionId},
    );
    return value == null ? null : WatchSyncEnvelope.fromMap(_map(value));
  }

  @override
  Future<void> forcePhoneControl(String staleWatchSessionId) =>
      _methodChannel.invokeMethod<void>('forcePhoneControl', {
        'watchSessionId': staleWatchSessionId,
      });

  @override
  Future<WatchSyncEnvelope?> drainPendingEnvelope() async {
    final value = await _methodChannel.invokeMethod<Object?>(
      'drainPendingEnvelope',
    );
    return value == null ? null : WatchSyncEnvelope.fromMap(_map(value));
  }

  @override
  Future<void> ackPersisted(WatchSyncEnvelope envelope) =>
      _methodChannel.invokeMethod<void>('ackPersisted', {
        'messageId': envelope.messageId,
        'matchId': envelope.matchId,
        'watchSessionId': envelope.watchSessionId,
        'revision': envelope.revision,
        'releaseControl':
            envelope.type == WatchSyncMessageType.requestPhoneControl,
      });

  WatchGatewayEvent _eventFromMap(Map<String, dynamic> map) {
    if (map['event'] == 'status') {
      return WatchStatusChanged(
        WatchConnectionStatus.fromMap(_map(map['status'])),
      );
    }
    return WatchEnvelopeReceived(
      WatchSyncEnvelope.fromMap(_map(map['envelope'] ?? map)),
    );
  }

  Map<String, dynamic> _map(Object? value) =>
      Map<String, dynamic>.from(value! as Map);
}
