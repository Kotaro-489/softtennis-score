import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../repositories/match_repository.dart';
import '../services/point_reason_policy.dart';
import '../services/score_rule_engine.dart';

enum ServeFaultOutcome { advancedToSecond, doubleFaultRecorded }

class MatchController extends StateNotifier<AsyncValue<MatchRecord?>> {
  MatchController(this._repository, this._engine, {this.onCompleted})
    : super(const AsyncLoading());
  final MatchRepository _repository;
  final ScoreRuleEngine _engine;
  final PointReasonPolicy _reasonPolicy = const PointReasonPolicy();
  final void Function()? onCompleted;
  var _isMutating = false;

  Future<void> load() async {
    try {
      state = AsyncData(await _repository.findInProgress());
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
    if (record == null || record.completedAt != null) return null;
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
    if (record == null || record.completedAt != null) return null;
    _isMutating = true;
    try {
      if (record.currentServeAttempt == ServeAttempt.first) {
        final updated = record.copyWith(
          currentServeAttempt: ServeAttempt.second,
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
    if (record == null || record.completedAt != null) return;
    if (record.currentServeAttempt == ServeAttempt.first &&
        record.events.isEmpty) {
      return;
    }
    _isMutating = true;
    final updated = record.currentServeAttempt == ServeAttempt.second
        ? record.copyWith(currentServeAttempt: ServeAttempt.first)
        : record.copyWith(
            events: record.events.sublist(0, record.events.length - 1),
            currentServeAttempt: record.events.last.serveAttempt,
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
    if (record == null || record.events.isEmpty) return;
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
    final updated = record.copyWith(events: events);
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
    );
    if (_engine.evaluate(updated).isCompleted) {
      updated = updated.copyWith(completedAt: DateTime.now());
    }
    return updated;
  }

  void dismissCompleted() => state = const AsyncData(null);
}
