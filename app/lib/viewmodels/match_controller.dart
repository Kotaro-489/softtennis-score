import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../models/watch_sync_envelope.dart';
import '../repositories/match_repository.dart';
import '../services/point_reason_policy.dart';
import '../services/score_rule_engine.dart';
import '../services/watch_session_gateway.dart';

enum ServeFaultOutcome { advancedToSecond, doubleFaultRecorded }

class MatchController extends StateNotifier<AsyncValue<MatchRecord?>> {
  MatchController(
    this._repository,
    this._engine, {
    this.watchGateway = const NoopWatchSessionGateway(),
    this.onCompleted,
  }) : super(const AsyncLoading()) {
    _watchSubscription = watchGateway.events.listen(_handleWatchEvent);
  }
  final MatchRepository _repository;
  final ScoreRuleEngine _engine;
  final WatchSessionGateway watchGateway;
  final PointReasonPolicy _reasonPolicy = const PointReasonPolicy();
  final void Function()? onCompleted;
  var _isMutating = false;
  StreamSubscription<WatchGatewayEvent>? _watchSubscription;
  Future<void> _watchEventQueue = Future.value();

  @override
  void dispose() {
    unawaited(_watchSubscription?.cancel());
    super.dispose();
  }

  Future<void> load() async {
    try {
      state = AsyncData(await _repository.findInProgress());
      final pending = await watchGateway.drainPendingEnvelope();
      if (pending != null) await _applyWatchEnvelope(pending);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> start(MatchRecord record) async {
    state = const AsyncLoading();
    try {
      await _repository.save(record);
      state = AsyncData(record);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<String?> addPoint(Side side, {PointReason? reason}) async {
    if (_isMutating) return null;
    final record = state.valueOrNull;
    if (record == null || !_phoneCanEdit(record)) return null;
    if (reason != null) {
      final servingSide = _engine.evaluate(record).servingSide;
      if (!_reasonPolicy.isAllowed(
        reason: reason,
        servingSide: servingSide,
        winningSide: side,
        serveAttempt: record.currentServeAttempt,
      )) {
        return null;
      }
    }
    _isMutating = true;
    final eventId = DateTime.now().microsecondsSinceEpoch.toString();
    final updated = _recordWithPoint(record, eventId, side, reason: reason);
    try {
      await _repository.save(updated);
      state = AsyncData(updated);
      if (updated.completedAt != null) onCompleted?.call();
      return eventId;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    } finally {
      _isMutating = false;
    }
  }

  Future<ServeFaultOutcome?> recordFault() async {
    if (_isMutating) return null;
    final record = state.valueOrNull;
    if (record == null || !_phoneCanEdit(record)) return null;
    _isMutating = true;
    try {
      if (record.currentServeAttempt == ServeAttempt.first) {
        final updated = record.copyWith(
          currentServeAttempt: ServeAttempt.second,
          revision: record.revision + 1,
        );
        await _repository.save(updated);
        state = AsyncData(updated);
        return ServeFaultOutcome.advancedToSecond;
      }

      final receivingSide = _engine.evaluate(record).servingSide.other;
      final eventId = DateTime.now().microsecondsSinceEpoch.toString();
      final updated = _recordWithPoint(
        record,
        eventId,
        receivingSide,
        reason: PointReason.opponentDoubleFault,
      );
      await _repository.save(updated);
      state = AsyncData(updated);
      if (updated.completedAt != null) onCompleted?.call();
      return ServeFaultOutcome.doubleFaultRecorded;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return null;
    } finally {
      _isMutating = false;
    }
  }

  Future<void> undo() async {
    if (_isMutating) return;
    final record = state.valueOrNull;
    if (record == null || !_phoneCanEdit(record)) return;
    if (record.currentServeAttempt == ServeAttempt.first &&
        record.events.isEmpty) {
      return;
    }
    _isMutating = true;
    final updated = record.currentServeAttempt == ServeAttempt.second
        ? record.copyWith(
            currentServeAttempt: ServeAttempt.first,
            revision: record.revision + 1,
          )
        : record.copyWith(
            events: record.events.sublist(0, record.events.length - 1),
            currentServeAttempt: record.events.last.serveAttempt,
            revision: record.revision + 1,
          );
    try {
      await _repository.save(updated);
      state = AsyncData(updated);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } finally {
      _isMutating = false;
    }
  }

  Future<void> setPointReason(String eventId, PointReason reason) async {
    if (_isMutating) return;
    final record = state.valueOrNull;
    if (record == null || !_phoneCanEdit(record) || record.events.isEmpty) {
      return;
    }
    final context = _engine.contextForPoint(record, eventId);
    if (context == null ||
        !_reasonPolicy.isAllowed(
          reason: reason,
          servingSide: context.servingSide,
          winningSide: context.winningSide,
          serveAttempt: context.serveAttempt,
        )) {
      return;
    }
    _isMutating = true;
    final events = record.events.map((event) {
      if (event.id != eventId) return event;
      return PointEvent(
        id: event.id,
        winningSide: event.winningSide,
        createdAt: event.createdAt,
        serveAttempt: event.serveAttempt,
        reason: reason,
      );
    }).toList();
    final updated = record.copyWith(
      events: events,
      revision: record.revision + 1,
    );
    try {
      await _repository.save(updated);
      state = AsyncData(updated);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } finally {
      _isMutating = false;
    }
  }

  MatchRecord _recordWithPoint(
    MatchRecord record,
    String eventId,
    Side side, {
    PointReason? reason,
  }) {
    final events = [
      ...record.events,
      PointEvent(
        id: eventId,
        winningSide: side,
        reason: reason,
        serveAttempt: record.currentServeAttempt,
        createdAt: DateTime.now(),
      ),
    ];
    var updated = record.copyWith(
      events: events,
      currentServeAttempt: ServeAttempt.first,
      revision: record.revision + 1,
    );
    if (_engine.evaluate(updated).isCompleted) {
      updated = updated.copyWith(completedAt: DateTime.now());
    }
    return updated;
  }

  void dismissCompleted() => state = const AsyncData(null);

  Future<bool> handoffToWatch() async {
    if (_isMutating) return false;
    final record = state.valueOrNull;
    if (record == null || !_phoneCanEdit(record)) return false;
    _isMutating = true;
    final now = DateTime.now();
    final sessionId = 'watch-${now.microsecondsSinceEpoch}';
    final candidate = record.copyWith(
      scoreInputOwner: ScoreInputOwner.watch,
      revision: record.revision + 1,
      watchSessionId: sessionId,
    );
    final envelope = WatchSyncEnvelope(
      schemaVersion: WatchSyncEnvelope.currentSchemaVersion,
      messageId: 'handoff-${now.microsecondsSinceEpoch}',
      type: WatchSyncMessageType.handoff,
      matchId: record.id,
      watchSessionId: sessionId,
      revision: candidate.revision,
      sentAt: now,
      match: candidate,
    );
    try {
      if (!await watchGateway.handoffMatch(envelope)) return false;
      await _repository.save(candidate);
      state = AsyncData(candidate);
      return true;
    } catch (_) {
      await watchGateway.forcePhoneControl(sessionId);
      state = AsyncData(record);
      return false;
    } finally {
      _isMutating = false;
    }
  }

  Future<bool> requestPhoneControl() async {
    if (_isMutating) return false;
    final current = state.valueOrNull;
    if (current == null ||
        current.scoreInputOwner != ScoreInputOwner.watch ||
        current.watchSessionId == null) {
      return false;
    }
    _isMutating = true;
    try {
      final envelope = await watchGateway.requestPhoneControl(
        current.watchSessionId!,
      );
      if (envelope == null ||
          !await _applyWatchEnvelope(envelope, allowEqualRevision: true)) {
        return false;
      }
      final latest = state.valueOrNull!;
      final editable = latest.copyWith(
        scoreInputOwner: ScoreInputOwner.phone,
        revision: latest.revision + 1,
        clearWatchSessionId: true,
      );
      await _repository.save(editable);
      state = AsyncData(editable);
      await watchGateway.ackPersisted(
        WatchSyncEnvelope(
          schemaVersion: WatchSyncEnvelope.currentSchemaVersion,
          messageId: envelope.messageId,
          type: WatchSyncMessageType.requestPhoneControl,
          matchId: editable.id,
          watchSessionId: current.watchSessionId!,
          revision: editable.revision,
          sentAt: DateTime.now(),
          match: editable,
        ),
      );
      return true;
    } catch (_) {
      return false;
    } finally {
      _isMutating = false;
    }
  }

  Future<void> forcePhoneControl() async {
    if (_isMutating) return;
    final record = state.valueOrNull;
    if (record == null || record.watchSessionId == null) return;
    _isMutating = true;
    try {
      final staleSessionId = record.watchSessionId!;
      final updated = record.copyWith(
        scoreInputOwner: ScoreInputOwner.phone,
        revision: record.revision + 1,
        watchSessionId: 'invalidated-${DateTime.now().microsecondsSinceEpoch}',
      );
      await _repository.save(updated);
      state = AsyncData(updated);
      try {
        await watchGateway.forcePhoneControl(staleSessionId);
      } catch (_) {
        // 保存済みの新しいセッションIDが古いWatch更新を拒否する。
      }
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    } finally {
      _isMutating = false;
    }
  }

  bool _phoneCanEdit(MatchRecord? record) =>
      record != null &&
      record.completedAt == null &&
      record.scoreInputOwner == ScoreInputOwner.phone;

  void _handleWatchEvent(WatchGatewayEvent event) {
    if (event is WatchEnvelopeReceived) {
      final previous = _watchEventQueue;
      _watchEventQueue = () async {
        await previous;
        try {
          await _applyWatchEnvelope(event.envelope);
        } catch (_) {
          // 後続の同期を止めず、再配送される完全スナップショットを待つ。
        }
      }();
    }
  }

  Future<bool> _applyWatchEnvelope(
    WatchSyncEnvelope envelope, {
    bool allowEqualRevision = false,
  }) async {
    final current = state.valueOrNull;
    final incoming = envelope.match;
    if (current == null ||
        incoming == null ||
        envelope.schemaVersion != WatchSyncEnvelope.currentSchemaVersion ||
        envelope.matchId != current.id ||
        current.scoreInputOwner != ScoreInputOwner.watch ||
        envelope.watchSessionId != current.watchSessionId ||
        incoming.watchSessionId != current.watchSessionId ||
        envelope.revision != incoming.revision ||
        (allowEqualRevision
            ? envelope.revision < current.revision
            : envelope.revision <= current.revision)) {
      return false;
    }
    await _repository.save(incoming);
    state = AsyncData(incoming);
    await watchGateway.ackPersisted(envelope);
    if (incoming.completedAt != null) onCompleted?.call();
    return true;
  }
}
