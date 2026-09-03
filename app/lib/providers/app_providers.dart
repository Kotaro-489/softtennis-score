import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../repositories/match_repository.dart';
import '../repositories/sqlite_match_repository.dart';
import '../services/score_rule_engine.dart';
import '../viewmodels/match_controller.dart';

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => SqliteMatchRepository(),
);
final scoreRuleEngineProvider = Provider<ScoreRuleEngine>(
  (ref) => const ScoreRuleEngine(),
);
final completedMatchesProvider = FutureProvider.autoDispose<List<MatchRecord>>(
  (ref) => ref.read(matchRepositoryProvider).findCompleted(),
);
final matchControllerProvider =
    StateNotifierProvider<MatchController, AsyncValue<MatchRecord?>>((ref) {
      final controller = MatchController(
        ref.read(matchRepositoryProvider),
        ref.read(scoreRuleEngineProvider),
        onCompleted: () => ref.invalidate(completedMatchesProvider),
      );
      controller.load();
      return controller;
    });
