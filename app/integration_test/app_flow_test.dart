import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:softtennis_score/main.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/providers/app_providers.dart';
import 'package:softtennis_score/repositories/match_repository.dart';

class FlowRepository implements MatchRepository {
  MatchRecord? active;
  final completed = <MatchRecord>[];
  MyPairProfile? profile;

  @override
  Future<void> delete(String id) async =>
      completed.removeWhere((record) => record.id == id);
  @override
  Future<List<MatchRecord>> findCompleted() async => completed;
  @override
  Future<MatchRecord?> findInProgress() async => active;
  @override
  Future<MyPairProfile?> loadMyPairProfile() async => profile;
  @override
  Future<void> save(MatchRecord record) async => active = record;
  @override
  Future<void> saveMyPairProfile(MyPairProfile value) async => profile = value;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUi(WidgetTester tester) async {
    for (var frame = 0; frame < 5; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('試合作成・2ndサービス・得点・取消の主要導線', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(FlowRepository()),
        ],
        child: const SoftTennisScoreApp(),
      ),
    );
    await pumpUi(tester);

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(1), 'A');
    await tester.enterText(fields.at(2), 'B');
    await tester.enterText(fields.at(3), '相手ペア');
    await tester.enterText(fields.at(4), 'C');
    await tester.enterText(fields.at(5), 'D');
    FocusManager.instance.primaryFocus?.unfocus();
    await pumpUi(tester);
    final start = find.text('試合開始');
    await tester.scrollUntilVisible(
      start,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(start);
    await pumpUi(tester);

    expect(find.text('1stサービス'), findsOneWidget);
    await tester.tap(find.text('フォルト（2ndへ）'));
    await pumpUi(tester);
    expect(find.text('2ndサービス'), findsOneWidget);

    await tester.tap(find.text('＋ 1ポイント').first);
    await pumpUi(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('score-points-mine'))).data,
      '1',
    );

    await tester.tap(find.byIcon(Icons.undo));
    await pumpUi(tester);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('score-points-mine'))).data,
      '0',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('score-points-opponent')))
          .data,
      '0',
    );
    expect(find.text('2ndサービス'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo));
    await pumpUi(tester);
    expect(find.text('1stサービス'), findsOneWidget);

    await tester.tap(find.text('フォルト（2ndへ）'));
    await pumpUi(tester);
    await tester.tap(find.text('フォルト（ダブルフォルト）'));
    await pumpUi(tester);

    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('score-points-opponent')))
          .data,
      '1',
    );
    expect(find.text('ダブルフォルトを記録しました'), findsOneWidget);
  });
}
