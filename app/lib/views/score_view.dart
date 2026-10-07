import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_models.dart';
import '../providers/app_providers.dart';
import '../services/point_reason_policy.dart';
import '../services/score_rule_engine.dart';
import '../services/watch_session_gateway.dart';
import '../viewmodels/match_controller.dart';

class ScoreView extends ConsumerStatefulWidget {
  const ScoreView({super.key, required this.record});
  final MatchRecord record;

  @override
  ConsumerState<ScoreView> createState() => _ScoreViewState();
}

class _ScoreViewState extends ConsumerState<ScoreView> {
  String? _lastPointEventId;
  var _saving = false;

  MatchController get _controller => ref.read(matchControllerProvider.notifier);
  bool get _watchOwnsInput =>
      widget.record.scoreInputOwner == ScoreInputOwner.watch;
  bool get _inputDisabled => _saving || _watchOwnsInput;

  String _nameFor(String id) {
    final players = [
      ...widget.record.myPair.players,
      ...widget.record.opponentPair.players,
    ];
    return players.firstWhere((player) => player.id == id).name;
  }

  /// 保存中は操作を止め、画面が残っている場合だけ結果を表示する。
  Future<void> _perform<T>(
    Future<T> Function() action, {
    void Function(T result)? onSaved,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final result = await action();
      if (mounted) setState(() => onSaved?.call(result));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _point(Side side) => _perform(
    () => _controller.addPoint(side),
    onSaved: (eventId) => _lastPointEventId = eventId,
  );

  Future<void> _fault() => _perform(
    _controller.recordFault,
    onSaved: (outcome) {
      _lastPointEventId = null;
      if (outcome == ServeFaultOutcome.doubleFaultRecorded) {
        _notify('ダブルフォルトを記録しました');
      }
    },
  );

  Future<void> _undo() =>
      _perform(_controller.undo, onSaved: (_) => _lastPointEventId = null);

  Future<void> _setReason(PointReason reason) async {
    final eventId = _lastPointEventId;
    if (eventId == null) return;
    await _perform(
      () => _controller.setPointReason(eventId, reason),
      onSaved: (_) => _lastPointEventId = null,
    );
  }

  Future<void> _handoffToWatch() => _perform(
    _controller.handoffToWatch,
    onSaved: (accepted) =>
        _notify(accepted ? 'Apple Watchで記録を開始しました' : 'Apple Watchへ引き渡せませんでした'),
  );

  Future<void> _requestPhoneControl() => _perform(
    _controller.requestPhoneControl,
    onSaved: (restored) {
      if (!restored) _notify('Watchと通信できません。接続を確認してください。');
    },
  );

  void _notify(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _confirmForcePhoneControl() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('強制的にiPhoneへ戻しますか？'),
        content: const Text(
          'Watchに未同期の得点がある場合は失われます。Watchを接続できない場合だけ使用してください。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('強制的に戻す'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _perform(_controller.forcePhoneControl);
  }

  @override
  Widget build(BuildContext context) {
    final engine = ref.read(scoreRuleEngineProvider);
    final snapshot = engine.evaluate(widget.record);
    final lastPointContext = _lastPointEventId == null
        ? null
        : engine.contextForPoint(widget.record, _lastPointEventId!);
    final availableReasons = lastPointContext == null
        ? const <PointReason>[]
        : const PointReasonPolicy().availableReasons(
            servingSide: lastPointContext.servingSide,
            winningSide: lastPointContext.winningSide,
            serveAttempt: lastPointContext.serveAttempt,
          );
    final watchStatus = ref.watch(watchConnectionStatusProvider).valueOrNull;
    if (snapshot.isCompleted) {
      return _completedMatch(snapshot);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.record.format.label),
        actions: [
          if (!_watchOwnsInput && watchStatus?.supported == true)
            IconButton(
              onPressed: _saving || watchStatus?.canHandoff != true
                  ? null
                  : _handoffToWatch,
              icon: const Icon(Icons.watch),
              tooltip: 'Apple Watchで記録',
            ),
          IconButton(
            onPressed:
                _inputDisabled ||
                    (widget.record.events.isEmpty &&
                        widget.record.currentServeAttempt == ServeAttempt.first)
                ? null
                : _undo,
            icon: const Icon(Icons.undo),
            tooltip: widget.record.currentServeAttempt == ServeAttempt.second
                ? '1stフォルトを取り消す'
                : '直前のポイントを取り消す',
          ),
        ],
      ),
      body: _scoreBody(snapshot, watchStatus, availableReasons),
    );
  }

  Widget _completedMatch(ScoreSnapshot snapshot) => Scaffold(
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
                onPressed: _controller.dismissCompleted,
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

  Widget _scoreBody(
    ScoreSnapshot snapshot,
    WatchConnectionStatus? watchStatus,
    List<PointReason> availableReasons,
  ) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  if (_watchOwnsInput) _watchReadOnlyPanel(watchStatus),
                  ..._serviceInfo(snapshot),
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
                  if (availableReasons.isNotEmpty)
                    _reasonChips(availableReasons),
                  const SizedBox(height: 12),
                  const Text('理由は任意です。急ぐときは次の得点をそのまま押せます。'),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  /// ゲーム・サービス・交代案内を、元の表示順と余白で組み立てる。
  List<Widget> _serviceInfo(ScoreSnapshot snapshot) => [
    Text(
      snapshot.isFinalGame
          ? 'ファイナルゲーム'
          : 'ゲーム ${snapshot.myGames + snapshot.opponentGames + 1}',
      style: Theme.of(context).textTheme.titleLarge,
    ),
    Text(
      widget.record.deuceEnabled ? 'デュースあり' : 'デュースなし',
      style: Theme.of(context).textTheme.labelMedium,
    ),
    const SizedBox(height: 8),
    Text(
      'サービス: ${snapshot.servingSide.label}・${_nameFor(snapshot.serverId)} ／ レシーブ: ${_nameFor(snapshot.receiverId)}',
    ),
    const SizedBox(height: 8),
    Chip(
      avatar: const Icon(Icons.sports_tennis, size: 18),
      label: Text(widget.record.currentServeAttempt.label),
    ),
    const SizedBox(height: 8),
    OutlinedButton.icon(
      onPressed: _inputDisabled ? null : _fault,
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      icon: const Icon(Icons.warning_amber),
      label: Text(
        widget.record.currentServeAttempt == ServeAttempt.first
            ? 'フォルト（2ndへ）'
            : 'フォルト（ダブルフォルト）',
      ),
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
  ];

  Widget _reasonChips(List<PointReason> reasons) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final reason in reasons)
        ActionChip(
          label: Text(reason.label),
          onPressed: _inputDisabled ? null : () => _setReason(reason),
        ),
    ],
  );

  Widget _watchReadOnlyPanel(WatchConnectionStatus? status) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Apple Watchで記録中',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            status?.reachable == true
                ? '接続中・iPhoneは閲覧専用'
                : '未接続・Watchで記録を継続できます',
          ),
          if (status?.lastSyncAt != null)
            Text('最終同期: ${_clock(status!.lastSyncAt!)}'),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _saving || status?.reachable != true
                ? null
                : _requestPhoneControl,
            child: const Text('iPhoneで記録に戻す'),
          ),
          TextButton(
            onPressed: _saving ? null : _confirmForcePhoneControl,
            child: const Text('接続できない場合は強制的に戻す'),
          ),
        ],
      ),
    ),
  );

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  Widget _scoreCard(String name, int games, int points, Side side) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(name, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('ポイント', style: Theme.of(context).textTheme.labelLarge),
          Text(
            '$points',
            key: ValueKey('score-points-${side.name}'),
            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            'ゲーム $games',
            key: ValueKey('score-games-${side.name}'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _inputDisabled ? null : () => _point(side),
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
