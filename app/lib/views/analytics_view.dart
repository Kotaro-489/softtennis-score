import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../providers/app_providers.dart';
import '../services/match_analytics.dart';

enum AnalyticsPeriod { all, sevenDays, thirtyDays }

class AnalyticsView extends ConsumerStatefulWidget {
  const AnalyticsView({super.key});
  @override
  ConsumerState<AnalyticsView> createState() => _AnalyticsViewState();
}

class _AnalyticsViewState extends ConsumerState<AnalyticsView> {
  var _period = AnalyticsPeriod.all;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(completedMatchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('集計')),
      body: history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: FilledButton(
            onPressed: () => ref.invalidate(completedMatchesProvider),
            child: const Text('再読込'),
          ),
        ),
        data: (records) {
          final filtered = _filter(records);
          final analytics = MatchAnalytics.calculate(
            filtered,
            ref.read(scoreRuleEngineProvider),
          );
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<AnalyticsPeriod>(
                initialValue: _period,
                decoration: const InputDecoration(labelText: '期間'),
                items: const [
                  DropdownMenuItem(
                    value: AnalyticsPeriod.all,
                    child: Text('全期間'),
                  ),
                  DropdownMenuItem(
                    value: AnalyticsPeriod.sevenDays,
                    child: Text('過去7日'),
                  ),
                  DropdownMenuItem(
                    value: AnalyticsPeriod.thirtyDays,
                    child: Text('過去30日'),
                  ),
                ],
                onChanged: (value) => setState(() => _period = value!),
              ),
              const SizedBox(height: 20),
              Text(
                '勝率 ${analytics.winRate}%',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              Text('${analytics.matchCount}試合中 ${analytics.wins}勝'),
              const SizedBox(height: 20),
              Text('ゲーム取得率 ${(analytics.gameRate * 100).round()}%'),
              Text('ポイント取得率 ${(analytics.pointRate * 100).round()}%'),
              Text('最長連続得点 ${analytics.longestScoringRun}ポイント'),
              Text('未分類 ${analytics.unclassifiedPoints}ポイント'),
              const Divider(height: 32),
              _reasonSection('自分の得点理由', analytics.myReasons),
              _reasonSection('相手の得点理由', analytics.opponentReasons),
            ],
          );
        },
      ),
    );
  }

  List<MatchRecord> _filter(List<MatchRecord> records) {
    final days = switch (_period) {
      AnalyticsPeriod.all => null,
      AnalyticsPeriod.sevenDays => 7,
      AnalyticsPeriod.thirtyDays => 30,
    };
    if (days == null) return records;
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return records
        .where((record) => record.completedAt!.isAfter(cutoff))
        .toList();
  }

  Widget _reasonSection(String title, Map<PointReason, int> reasons) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (reasons.isEmpty) const Text('分類されたポイントはありません。'),
      ...PointReason.values
          .where(reasons.containsKey)
          .map(
            (reason) => ListTile(
              title: Text(reason.label),
              trailing: Text('${reasons[reason]}'),
            ),
          ),
      const SizedBox(height: 16),
    ],
  );
}
