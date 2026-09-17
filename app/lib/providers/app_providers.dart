import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../repositories/match_repository.dart';
import '../repositories/sqlite_match_repository.dart';
import '../services/score_rule_engine.dart';
import '../services/watch_session_gateway.dart';
import '../viewmodels/match_controller.dart';

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => SqliteMatchRepository(),
);
final scoreRuleEngineProvider = Provider<ScoreRuleEngine>(
  (ref) => const ScoreRuleEngine(),
);
final watchSessionGatewayProvider = Provider<WatchSessionGateway>((ref) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    return MethodChannelWatchSessionGateway();
  }
  return const NoopWatchSessionGateway();
});
final watchConnectionStatusProvider = StreamProvider<WatchConnectionStatus>((
  ref,
) async* {
  final gateway = ref.read(watchSessionGatewayProvider);
  yield await gateway.getStatus();
  await for (final event in gateway.events) {
    if (event is WatchStatusChanged) yield event.status;
  }
});
final completedMatchesProvider = FutureProvider.autoDispose<List<MatchRecord>>(
  (ref) => ref.read(matchRepositoryProvider).findCompleted(),
);
final matchControllerProvider =
    StateNotifierProvider<MatchController, AsyncValue<MatchRecord?>>((ref) {
      final controller = MatchController(
        ref.read(matchRepositoryProvider),
        ref.read(scoreRuleEngineProvider),
        watchGateway: ref.read(watchSessionGatewayProvider),
        onCompleted: () => ref.invalidate(completedMatchesProvider),
      );
      controller.load();
      return controller;
    });
