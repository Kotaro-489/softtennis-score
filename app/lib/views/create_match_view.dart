import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../providers/app_providers.dart';

class CreateMatchView extends ConsumerStatefulWidget {
  const CreateMatchView({super.key});

  @override
  ConsumerState<CreateMatchView> createState() => _CreateMatchViewState();
}

class _CreateMatchViewState extends ConsumerState<CreateMatchView> {
  final _myPair = TextEditingController(text: '自分ペア');
  final _opponentPair = TextEditingController();
  final _myFirst = TextEditingController();
  final _mySecond = TextEditingController();
  final _opponentFirst = TextEditingController();
  final _opponentSecond = TextEditingController();
  MatchFormatPreset _format = MatchFormatPreset.officialFive;
  Side _servingSide = Side.mine;
  var _serverIndex = 0;
  var _receiverIndex = 0;

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      final profile = await ref
          .read(matchRepositoryProvider)
          .loadMyPairProfile();
      if (!mounted || profile == null) return;
      _myPair.text = profile.pairName;
      _myFirst.text = profile.firstPlayerName;
      _mySecond.text = profile.secondPlayerName;
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _myPair,
      _opponentPair,
      _myFirst,
      _mySecond,
      _opponentFirst,
      _opponentSecond,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _start() async {
    final required = [
      _myPair,
      _opponentPair,
      _myFirst,
      _mySecond,
      _opponentFirst,
      _opponentSecond,
    ];
    if (required.any((controller) => controller.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('ペア名と4選手名を入力してください。')));
      return;
    }
    final now = DateTime.now();
    final id = now.microsecondsSinceEpoch.toString();
    final myPlayers = [
      Player(id: '$id-my-1', name: _myFirst.text.trim()),
      Player(id: '$id-my-2', name: _mySecond.text.trim()),
    ];
    final opponentPlayers = [
      Player(id: '$id-op-1', name: _opponentFirst.text.trim()),
      Player(id: '$id-op-2', name: _opponentSecond.text.trim()),
    ];
    final record = MatchRecord(
      id: id,
      myPair: Pair(id: '$id-my', name: _myPair.text.trim(), players: myPlayers),
      opponentPair: Pair(
        id: '$id-op',
        name: _opponentPair.text.trim(),
        players: opponentPlayers,
      ),
      format: _format,
      firstServingSide: _servingSide,
      firstServerId: _servingSide == Side.mine
          ? myPlayers[_serverIndex].id
          : opponentPlayers[_serverIndex].id,
      firstReceiverId: _servingSide == Side.mine
          ? opponentPlayers[_receiverIndex].id
          : myPlayers[_receiverIndex].id,
      createdAt: now,
    );
    try {
      await ref
          .read(matchRepositoryProvider)
          .saveMyPairProfile(
            MyPairProfile(
              pairName: _myPair.text.trim(),
              firstPlayerName: _myFirst.text.trim(),
              secondPlayerName: _mySecond.text.trim(),
            ),
          );
      await ref.read(matchControllerProvider.notifier).start(record);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('試合を保存できませんでした。もう一度お試しください。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('試合を作成')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('自分ペア', style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _myPair,
            decoration: const InputDecoration(labelText: 'ペア名'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _myFirst,
                  decoration: const InputDecoration(labelText: '選手1'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _mySecond,
                  decoration: const InputDecoration(labelText: '選手2'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('相手ペア', style: Theme.of(context).textTheme.titleMedium),
          TextField(
            controller: _opponentPair,
            decoration: const InputDecoration(labelText: 'ペア名'),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _opponentFirst,
                  decoration: const InputDecoration(labelText: '選手1'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _opponentSecond,
                  decoration: const InputDecoration(labelText: '選手2'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField(
            initialValue: _format,
            decoration: const InputDecoration(labelText: '試合形式'),
            items: MatchFormatPreset.values
                .map(
                  (format) => DropdownMenuItem(
                    value: format,
                    child: Text(format.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _format = value!),
          ),
          const SizedBox(height: 12),
          Text('先にサービスするペア', style: Theme.of(context).textTheme.labelLarge),
          SegmentedButton<Side>(
            segments: const [
              ButtonSegment(value: Side.mine, label: Text('自分')),
              ButtonSegment(value: Side.opponent, label: Text('相手')),
            ],
            selected: {_servingSide},
            onSelectionChanged: (value) =>
                setState(() => _servingSide = value.first),
          ),
          const SizedBox(height: 12),
          Text('最初のサーバー', style: Theme.of(context).textTheme.labelLarge),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('選手1')),
              ButtonSegment(value: 1, label: Text('選手2')),
            ],
            selected: {_serverIndex},
            onSelectionChanged: (value) =>
                setState(() => _serverIndex = value.first),
          ),
          const SizedBox(height: 8),
          Text('最初のレシーバー', style: Theme.of(context).textTheme.labelLarge),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('選手1')),
              ButtonSegment(value: 1, label: Text('選手2')),
            ],
            selected: {_receiverIndex},
            onSelectionChanged: (value) =>
                setState(() => _receiverIndex = value.first),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _start,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('試合開始'),
          ),
        ],
      ),
    ),
  );
}
