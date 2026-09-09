import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:softtennis_score/main.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/providers/app_providers.dart';
import 'package:softtennis_score/repositories/match_repository.dart';
import 'package:softtennis_score/views/score_view.dart';

class FakeMatchRepository implements MatchRepository {
  FakeMatchRepository({this.active});

  MatchRecord? active;

  @override
  Future<void> delete(String id) async {}
  @override
  Future<List<MatchRecord>> findCompleted() async => [];
  @override
  Future<MatchRecord?> findInProgress() async => active;
  @override
  Future<MyPairProfile?> loadMyPairProfile() async => null;
  @override
  Future<void> save(MatchRecord record) async => active = record;
  @override
  Future<void> saveMyPairProfile(MyPairProfile profile) async {}
}

void main() {
  MatchRecord activeRecord() => MatchRecord(
    id: 'match',
    myPair: const Pair(
      id: 'mine',
      name: '自分',
      players: [
        Player(id: 'm1', name: 'A'),
        Player(id: 'm2', name: 'B'),
      ],
    ),
    opponentPair: const Pair(
      id: 'opponent',
      name: '相手',
      players: [
        Player(id: 'o1', name: 'C'),
        Player(id: 'o2', name: 'D'),
      ],
    ),
    format: MatchFormatPreset.officialFive,
    firstServingSide: Side.mine,
    firstServerId: 'm1',
    firstReceiverId: 'o1',
    createdAt: DateTime(2026),
  );

  testWidgets('アプリは試合作成画面を表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(FakeMatchRepository()),
        ],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('試合を作成'), findsOneWidget);
  });

  testWidgets('文字を拡大しても操作ボタンは44px以上ある', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(FakeMatchRepository()),
        ],
        child: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SoftTennisScoreApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, '試合開始');
    await tester.scrollUntilVisible(
      button,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('システムのダークモードを反映する', (tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(FakeMatchRepository()),
        ],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('得点画面は文字拡大時も大きな得点ボタンを表示する', (tester) async {
    final record = activeRecord();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(FakeMatchRepository()),
        ],
        child: MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: ScoreView(record: record),
          ),
        ),
      ),
    );
    await tester.pump();
    final buttons = find.widgetWithText(FilledButton, '＋ 1ポイント');
    expect(buttons, findsNWidgets(2));
    expect(tester.getSize(buttons.first).height, greaterThanOrEqualTo(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('フォルト操作で1stから2ndへ切り替わる', (tester) async {
    final repository = FakeMatchRepository(active: activeRecord());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [matchRepositoryProvider.overrideWithValue(repository)],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1stサービス'), findsOneWidget);
    final firstFaultButton = find.widgetWithText(OutlinedButton, 'フォルト（2ndへ）');
    expect(tester.getSize(firstFaultButton).height, greaterThanOrEqualTo(44));
    await tester.tap(firstFaultButton);
    await tester.pumpAndSettle();

    expect(find.text('2ndサービス'), findsOneWidget);
    expect(find.text('フォルト（ダブルフォルト）'), findsOneWidget);
  });

  testWidgets('サービス側得点では不整合な理由を表示しない', (tester) async {
    final repository = FakeMatchRepository(active: activeRecord());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [matchRepositoryProvider.overrideWithValue(repository)],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('＋ 1ポイント').first);
    await tester.pumpAndSettle();

    expect(find.text('サービスエース'), findsOneWidget);
    expect(find.text('リターンエース'), findsNothing);
    expect(find.text('相手のダブルフォルト'), findsNothing);
  });

  testWidgets('2ndのレシーブ側得点ではリターンとダブルフォルトを表示する', (tester) async {
    final repository = FakeMatchRepository(active: activeRecord());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [matchRepositoryProvider.overrideWithValue(repository)],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('フォルト（2ndへ）'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('＋ 1ポイント').last);
    await tester.pumpAndSettle();

    expect(find.text('サービスエース'), findsNothing);
    expect(find.text('リターンエース'), findsOneWidget);
    expect(find.text('相手のダブルフォルト'), findsOneWidget);
  });
}
