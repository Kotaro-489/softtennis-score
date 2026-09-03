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

  testWidgets('試合作成・得点・取消の主要導線', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchRepositoryProvider.overrideWithValue(FlowRepository()),
        ],
        child: const SoftTennisScoreApp(),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(1), 'A');
    await tester.enterText(fields.at(2), 'B');
    await tester.enterText(fields.at(3), '相手ペア');
    await tester.enterText(fields.at(4), 'C');
    await tester.enterText(fields.at(5), 'D');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final start = find.text('試合開始');
    await tester.scrollUntilVisible(
      start,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(start);
    await tester.pumpAndSettle();

    await tester.tap(find.text('＋ 1ポイント').first);
    await tester.pumpAndSettle();
    expect(find.text('ポイント 1'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pumpAndSettle();
    expect(find.text('ポイント 0'), findsNWidgets(2));
  });
}
