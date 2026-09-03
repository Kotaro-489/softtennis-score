import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../providers/app_providers.dart';

class ScoreView extends ConsumerStatefulWidget {
  const ScoreView({super.key, required this.record});
  final MatchRecord record;

  @override
  ConsumerState<ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends ConsumerState<ScoreView> {
  String? _lastPointEventId;
  var _saving = false;

  String _nameFor(String id) {
    final players = [
      ...widget.record.myPair.players,
      ...widget.record.opponentPair.players,
    ];
    return players.firstWhere((player) => player.id == id).name;
  }

  Future<void> _point(Side side) async {
    if (_saving) return;
    setState(() => _saving = true);
    final eventId = await ref
        .read(matchControllerProvider.notifier)
        .addPoint(side);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _lastPointEventId = eventId;
    });
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.read(scoreRuleEngineProvider).evaluate(widget.record);
    if (snapshot.isCompleted) {
      return Scaffold(
        appBar: AppBar(title: const Text('試合終了')),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 72),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.record.myPair.name} ${snapshot.myGames} - ${snapshot.opponentGames} ${widget.record.opponentPair.name}',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => ref
                        .read(matchControllerProvider.notifier)
                        .dismissCompleted(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: const Text('完了して次の試合へ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record.format.label),
        actions: [
          IconButton(
            onPressed: widget.record.events.isEmpty
                ? null
                : () => ref.read(matchControllerProvider.notifier).undo(),
            icon: const Icon(Icons.undo),
            tooltip: '直前のポイントを取り消す',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                snapshot.isFinalGame
                    ? 'ファイナルゲーム'
                    : 'ゲーム ${snapshot.myGames + snapshot.opponentGames + 1}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'サービス: ${snapshot.servingSide.label}・${_nameFor(snapshot.serverId)} ／ レシーブ: ${_nameFor(snapshot.receiverId)}',
              ),
              if (snapshot.shouldChangeSides)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Chip(label: Text('チェンジサイズ')),
                ),
              if (snapshot.shouldChangeService && !snapshot.shouldChangeSides)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Chip(label: Text('チェンジサービス')),
                ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _scoreCard(
                      widget.record.myPair.name,
                      snapshot.myGames,
                      snapshot.myPoints,
                      Side.mine,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _scoreCard(
                      widget.record.opponentPair.name,
                      snapshot.opponentGames,
                      snapshot.opponentPoints,
                      Side.opponent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_lastPointEventId != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: PointReason.values
                      .map(
                        (reason) => ActionChip(
                          label: Text(reason.label),
                          onPressed: () async {
                            setState(() => _saving = true);
                            await ref
                                .read(matchControllerProvider.notifier)
                                .setPointReason(_lastPointEventId!, reason);
                            if (mounted) {
                              setState(() {
                                _saving = false;
                                _lastPointEventId = null;
                              });
                            }
                          },
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 12),
              const Text('理由は任意です。急ぐときは次の得点をそのまま押せます。'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreCard(String name, int games, int points, Side side) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(name, textAlign: TextAlign.center),
          Text(
            '$games',
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          Text('ポイント $points'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : () => _point(side),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(72),
            ),
            child: const Text('＋ 1ポイント'),
          ),
        ],
      ),
    ),
  );
}
