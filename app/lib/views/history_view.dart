import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../providers/app_providers.dart';
import '../services/score_rule_engine.dart';

class MatchHistoryView extends ConsumerWidget {
  const MatchHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(completedMatchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('試合履歴')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: '$error',
          onRetry: () => ref.invalidate(completedMatchesProvider),
        ),
        data: (records) => records.isEmpty
            ? const Center(child: Text('完了した試合はありません。'))
            : ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final record = records[index];
                  final score = ref
                      .read(scoreRuleEngineProvider)
                      .evaluate(record);
                  return ListTile(
                    title: Text(
                      '${record.myPair.name} ${score.myGames} - ${score.opponentGames} ${record.opponentPair.name}',
                    ),
                    subtitle: Text(
                      '${record.format.label}  ${_date(record.completedAt!)}',
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchDetailView(record: record),
                      ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: '削除',
                      onPressed: () => _delete(context, ref, record),
                    ),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    MatchRecord record,
  ) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('試合記録を削除しますか？'),
        content: const Text('削除した記録は元に戻せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (approved != true) return;
    await ref.read(matchRepositoryProvider).delete(record.id);
    ref.invalidate(completedMatchesProvider);
  }

  String _date(DateTime value) => value.toLocal().toString().substring(0, 16);
}

class MatchDetailView extends ConsumerWidget {
  const MatchDetailView({super.key, required this.record});
  final MatchRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.read(scoreRuleEngineProvider);
    final result = engine.evaluate(record);
    return Scaffold(
      appBar: AppBar(title: const Text('試合詳細')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${record.myPair.name} ${result.myGames} - ${result.opponentGames} ${record.opponentPair.name}',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(record.format.label, textAlign: TextAlign.center),
          const Divider(height: 32),
          Text('ポイント履歴', style: Theme.of(context).textTheme.titleLarge),
          for (var index = 0; index < record.events.length; index++)
            _eventTile(engine, index),
        ],
      ),
    );
  }

  Widget _eventTile(ScoreRuleEngine engine, int index) {
    final event = record.events[index];
    final partial = record.copyWith(
      events: record.events.sublist(0, index + 1),
      clearCompletedAt: true,
    );
    final score = engine.evaluate(partial);
    return ListTile(
      dense: true,
      leading: CircleAvatar(child: Text('${index + 1}')),
      title: Text(
        '${event.winningSide.label}が得点　${score.myGames}-${score.opponentGames} / ${score.myPoints}-${score.opponentPoints}',
      ),
      subtitle: Text(event.reason?.label ?? '未分類'),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('読み込めませんでした\n$message', textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('再試行')),
      ],
    ),
  );
}
