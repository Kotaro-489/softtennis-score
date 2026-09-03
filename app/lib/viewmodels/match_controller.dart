import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../repositories/match_repository.dart';
import '../services/score_rule_engine.dart';

class MatchController extends StateNotifier<AsyncValue<MatchRecord?>> {
  MatchController(this._repository, this._engine, {this.onCompleted})
    : super(const AsyncLoading());
  final MatchRepository _repository;
  final ScoreRuleEngine _engine;
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
    _isMutating = true;
    final eventId = DateTime.now().microsecondsSinceEpoch.toString();
    final events = [
      ...record.events,
      PointEvent(
        id: eventId,
        winningSide: side,
        reason: reason,
        createdAt: DateTime.now(),
      ),
    ];
    var updated = record.copyWith(events: events);
    if (_engine.evaluate(updated).isCompleted) {
      updated = updated.copyWith(completedAt: DateTime.now());
    }
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

  Future<void> undo() async {
    if (_isMutating) return;
    final record = state.valueOrNull;
    if (record == null || record.events.isEmpty) return;
    _isMutating = true;
    final updated = record.copyWith(
      events: record.events.sublist(0, record.events.length - 1),
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
    _isMutating = true;
    final events = record.events.map((event) {
      if (event.id != eventId) return event;
      return PointEvent(
        id: event.id,
        winningSide: event.winningSide,
        createdAt: event.createdAt,
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

  void dismissCompleted() => state = const AsyncData(null);
}
