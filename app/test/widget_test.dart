import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:softtennis_score/main.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/providers/app_providers.dart';
import 'package:softtennis_score/services/watch_session_gateway.dart';
import 'package:softtennis_score/views/history_view.dart';
import 'package:softtennis_score/views/score_view.dart';

import 'support/match_fixtures.dart';
import 'support/memory_match_repository.dart';

void main() {
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    testWidgets('${platform.name}は文字拡大とダーク表示でも入力・保存中の操作制御を維持する', (
      tester,
    ) async {
      tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(() {
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue();
      });
      final repository = MemoryMatchRepository(record: matchRecord());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            matchRepositoryProvider.overrideWithValue(repository),
            watchSessionGatewayProvider.overrideWithValue(
              const NoopWatchSessionGateway(),
            ),
          ],
          child: const SoftTennisScoreApp(),
        ),
      );
      await tester.pumpAndSettle();
      final scoreContext = tester.element(find.byType(ScoreView));
      expect(MediaQuery.textScalerOf(scoreContext).scale(10), 20);
      expect(Theme.of(scoreContext).brightness, Brightness.dark);
      final points = find.widgetWithText(FilledButton, '＋ 1ポイント');
      await tester.ensureVisible(points.first);
      await tester.tap(points.first);
      await tester.pumpAndSettle();
      final reason = find.widgetWithText(ActionChip, 'サービスエース');
      await tester.ensureVisible(reason);
      repository.saveGate = Completer<void>();
      await tester.tap(reason);
      await tester.pump();

      expect(tester.widget<ActionChip>(reason).onPressed, isNull);
      expect(
        tester
            .widget<OutlinedButton>(find.byType(OutlinedButton).first)
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
            .onPressed,
        isNull,
      );
      for (final button in tester.widgetList<FilledButton>(points)) {
        expect(button.onPressed, isNull);
      }
      expect(tester.getSize(points.first).height, greaterThanOrEqualTo(44));
      repository.saveGate!.complete();
      await tester.pumpAndSettle();
      expect(repository.record!.events.single.reason, PointReason.serviceAce);
      expect(repository.record!.revision, 2);
      expect(find.text('サービスエース'), findsNothing);
      expect(tester.widget<FilledButton>(points.first).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    }, variant: TargetPlatformVariant({platform}));
  }

  testWidgets('アプリは試合作成画面を表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(MemoryMatchRepository()),
        ],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('試合を作成'), findsOneWidget);
    expect(find.text('デュース'), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {true},
    );
  });

  testWidgets('形式変更時に従来値へ戻し、選択したデュース設定を保存する', (tester) async {
    final repository = MemoryMatchRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [matchRepositoryProvider.overrideWithValue(repository)],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<MatchFormatPreset>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3ゲーム').last);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {false},
    );

    await tester.tap(find.text('あり'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'A');
    await tester.enterText(fields.at(2), 'B');
    await tester.enterText(fields.at(3), '相手ペア');
    await tester.enterText(fields.at(4), 'C');
    await tester.enterText(fields.at(5), 'D');
    final start = find.widgetWithText(FilledButton, '試合開始');
    await tester.scrollUntilVisible(
      start,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(start);
    await tester.pumpAndSettle();

    expect(repository.record!.format, MatchFormatPreset.practiceThree);
    expect(repository.record!.deuceEnabled, isTrue);
  });

  testWidgets('文字を拡大しても操作ボタンは44px以上ある', (tester) async {
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(MemoryMatchRepository()),
        ],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();
    final button = find.widgetWithText(FilledButton, '試合開始');
    final deuceControl = find.byType(SegmentedButton<bool>);
    await tester.scrollUntilVisible(
      deuceControl,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.getSize(deuceControl).height, greaterThanOrEqualTo(44));
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
          matchRepositoryProvider.overrideWithValue(MemoryMatchRepository()),
        ],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    expect(Theme.of(context).brightness, Brightness.dark);
  });

  testWidgets('得点画面は文字拡大時も大きな得点ボタンを表示する', (tester) async {
    final record = matchRecord();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(MemoryMatchRepository()),
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

  testWidgets('得点画面はポイントをゲーム数より大きく表示する', (tester) async {
    final record = matchRecord();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(MemoryMatchRepository()),
        ],
        child: MaterialApp(home: ScoreView(record: record)),
      ),
    );
    await tester.pump();

    final points = tester.widget<Text>(
      find.byKey(const ValueKey('score-points-mine')),
    );
    final games = tester.widget<Text>(
      find.byKey(const ValueKey('score-games-mine')),
    );

    expect(points.data, '0');
    expect(games.data, 'ゲーム 0');
    expect(points.style!.fontSize, greaterThan(games.style!.fontSize!));
    expect(points.style!.fontWeight, FontWeight.bold);
    expect(find.text('デュースあり'), findsOneWidget);
  });

  testWidgets('履歴詳細にデュース設定を表示する', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(MemoryMatchRepository()),
        ],
        child: MaterialApp(
          home: MatchDetailView(record: matchRecord(deuceEnabled: false)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('5ゲーム・デュースなし'), findsOneWidget);
  });

  testWidgets('フォルト操作で1stから2ndへ切り替わる', (tester) async {
    final repository = MemoryMatchRepository(record: matchRecord());
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
    final repository = MemoryMatchRepository(record: matchRecord());
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
    final repository = MemoryMatchRepository(record: matchRecord());
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

  testWidgets('Watch編集中はiPhoneを閲覧専用にする', (tester) async {
    final record = matchRecord().copyWith(
      scoreInputOwner: ScoreInputOwner.watch,
      revision: 1,
      watchSessionId: 'watch-1',
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(
            MemoryMatchRepository(record: record),
          ),
        ],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apple Watchで記録中'), findsOneWidget);
    final scoreButtons = tester.widgetList<FilledButton>(
      find.widgetWithText(FilledButton, '＋ 1ポイント'),
    );
    expect(scoreButtons.every((button) => button.onPressed == null), isTrue);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'フォルト（2ndへ）'),
          )
          .onPressed,
      isNull,
    );
  });
}
