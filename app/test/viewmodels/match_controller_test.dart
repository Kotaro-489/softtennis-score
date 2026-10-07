import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/models/watch_sync_envelope.dart';
import 'package:softtennis_score/services/score_rule_engine.dart';
import 'package:softtennis_score/services/watch_session_gateway.dart';
import 'package:softtennis_score/viewmodels/match_controller.dart';

import '../support/match_fixtures.dart';
import '../support/memory_match_repository.dart';

class FakeWatchSessionGateway implements WatchSessionGateway {
  final eventsController = StreamController<WatchGatewayEvent>.broadcast();
  var acceptHandoff = true;
  WatchSyncEnvelope? handedOff;
  WatchSyncEnvelope? phoneControlResponse;
  final acknowledged = <String>[];
  final acknowledgedTypes = <WatchSyncMessageType>[];

  @override
  Stream<WatchGatewayEvent> get events => eventsController.stream;
  @override
  Future<void> ackPersisted(WatchSyncEnvelope envelope) async {
    acknowledged.add(envelope.messageId);
    acknowledgedTypes.add(envelope.type);
  }

  @override
  Future<WatchSyncEnvelope?> drainPendingEnvelope() async => null;
  @override
  Future<void> forcePhoneControl(String staleWatchSessionId) async {}
  @override
  Future<WatchConnectionStatus> getStatus() async =>
      const WatchConnectionStatus(
        supported: true,
        paired: true,
        appInstalled: true,
        reachable: true,
      );
  @override
  Future<bool> handoffMatch(WatchSyncEnvelope envelope) async {
    handedOff = envelope;
    return acceptHandoff;
  }

  @override
  Future<WatchSyncEnvelope?> requestPhoneControl(String watchSessionId) async =>
      phoneControlResponse;
}

void main() {
  final edits = <String, Future<void> Function(MatchController)>{
    '得点': (controller) async {
      await controller.addPoint(Side.mine);
    },
    '1stフォルト': (controller) async {
      await controller.recordFault();
    },
    '2ndフォルト': (controller) async {
      await controller.recordFault();
    },
    '取消': (controller) => controller.undo(),
    '理由': (controller) =>
        controller.setPointReason('0', PointReason.serviceAce),
  };

  for (final edit in edits.entries) {
    final initial = matchRecord(winners: [Side.mine]).copyWith(
      currentServeAttempt: edit.key == '2ndフォルト'
          ? ServeAttempt.second
          : ServeAttempt.first,
    );

    test('${edit.key}の保存中は状態を変えず、別の編集も受け付けない', () async {
      final repository = MemoryMatchRepository();
      final controller = MatchController(repository, const ScoreRuleEngine());
      addTearDown(controller.dispose);
      await controller.start(initial);
      repository.saveGate = Completer<void>();

      final pending = edit.value(controller);
      expect(controller.state.valueOrNull, same(initial));
      expect(await controller.addPoint(Side.opponent), isNull);
      expect(await controller.recordFault(), isNull);
      await controller.undo();
      await controller.setPointReason('0', PointReason.rallyWinner);
      expect(await controller.handoffToWatch(), isFalse);
      expect(repository.record, same(initial));

      repository.saveGate!.complete();
      await pending;
      expect(repository.record!.revision, 1);
      expect(controller.state.valueOrNull, same(repository.record));
    });

    test('${edit.key}の保存失敗後は保存済み状態を復元して再編集できる', () async {
      final repository = MemoryMatchRepository();
      final controller = MatchController(repository, const ScoreRuleEngine());
      addTearDown(controller.dispose);
      await controller.start(initial);
      final failure = StateError('保存失敗');
      repository.saveError = failure;

      await edit.value(controller);
      expect(controller.state.error, same(failure));
      expect(repository.record, same(initial));

      repository.saveError = null;
      await controller.load();
      expect(controller.state.valueOrNull, same(initial));
      await edit.value(controller);
      expect(repository.record!.revision, 1);
      expect(controller.state.hasError, isFalse);
    });
  }

  for (final doubleFault in [false, true]) {
    test('${doubleFault ? 'ダブルフォルト' : '通常得点'}による完了は保存後に一度だけ通知する', () async {
      final repository = MemoryMatchRepository();
      var completions = 0;
      final controller = MatchController(
        repository,
        const ScoreRuleEngine(),
        onCompleted: () {
          expect(repository.record!.completedAt, isNotNull);
          completions++;
        },
      );
      addTearDown(controller.dispose);
      await controller.start(
        matchRecord(
          format: MatchFormatPreset.practiceThree,
          winners: List.filled(7, Side.mine),
        ).copyWith(
          currentServeAttempt: doubleFault
              ? ServeAttempt.second
              : ServeAttempt.first,
        ),
      );

      if (doubleFault) {
        expect(
          await controller.recordFault(),
          ServeFaultOutcome.doubleFaultRecorded,
        );
      } else {
        await controller.addPoint(Side.mine);
      }
      final completed = repository.record!;
      expect(completed.events, hasLength(8));
      expect(completed.revision, 1);
      expect(completions, 1);
      await controller.addPoint(Side.mine);
      await controller.recordFault();
      await controller.undo();
      await controller.setPointReason(
        completed.events.last.id,
        PointReason.other,
      );
      expect(repository.record, same(completed));
      expect(completions, 1);
    });
  }

  test('得点は保存され、取消でイベント履歴を1件戻す', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(matchRecord());
    await controller.addPoint(Side.mine, reason: PointReason.rallyWinner);
    expect(repository.record!.events, hasLength(1));
    expect(repository.record!.events.single.reason, PointReason.rallyWinner);

    await controller.undo();
    expect(repository.record!.events, isEmpty);
  });

  test('未完了試合は再読込みできる', () async {
    final repository = MemoryMatchRepository();
    final first = MatchController(repository, const ScoreRuleEngine());
    await first.start(matchRecord());
    await first.addPoint(Side.opponent);

    final restored = MatchController(repository, const ScoreRuleEngine());
    await restored.load();
    expect(restored.state.valueOrNull!.events, hasLength(1));
  });

  test('イベントIDを指定して得点理由を更新する', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(matchRecord());
    final firstId = await controller.addPoint(Side.mine);
    await controller.addPoint(Side.opponent);
    await controller.setPointReason(firstId!, PointReason.serviceAce);

    expect(repository.record!.events.first.reason, PointReason.serviceAce);
    expect(repository.record!.events.last.reason, isNull);
  });

  test('1stフォルトは2ndへ進み、次の通常得点にサービス回数を保存する', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(matchRecord());

    final outcome = await controller.recordFault();
    expect(outcome, ServeFaultOutcome.advancedToSecond);
    expect(repository.record!.events, isEmpty);
    expect(repository.record!.currentServeAttempt, ServeAttempt.second);

    await controller.addPoint(Side.mine);
    expect(repository.record!.events.single.serveAttempt, ServeAttempt.second);
    expect(repository.record!.currentServeAttempt, ServeAttempt.first);
  });

  test('2ndフォルトはレシーブ側へ得点とダブルフォルト理由を保存する', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(matchRecord());

    await controller.recordFault();
    final outcome = await controller.recordFault();

    expect(outcome, ServeFaultOutcome.doubleFaultRecorded);
    final event = repository.record!.events.single;
    expect(event.winningSide, Side.opponent);
    expect(event.reason, PointReason.opponentDoubleFault);
    expect(event.serveAttempt, ServeAttempt.second);
    expect(repository.record!.currentServeAttempt, ServeAttempt.first);
  });

  test('2ndで終了したポイントを取り消すと2ndへ戻り、再取消で1stへ戻る', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(matchRecord());
    await controller.recordFault();
    await controller.addPoint(Side.mine);

    await controller.undo();
    expect(repository.record!.events, isEmpty);
    expect(repository.record!.currentServeAttempt, ServeAttempt.second);

    await controller.undo();
    expect(repository.record!.events, isEmpty);
    expect(repository.record!.currentServeAttempt, ServeAttempt.first);
  });

  test('サービス状況と矛盾する得点理由は保存しない', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(matchRecord());

    expect(
      await controller.addPoint(Side.mine, reason: PointReason.returnAce),
      isNull,
    );
    expect(repository.record!.events, isEmpty);

    final eventId = await controller.addPoint(Side.mine);
    await controller.setPointReason(eventId!, PointReason.opponentDoubleFault);
    expect(repository.record!.events.single.reason, isNull);
  });

  test('得点・フォルト・理由・取消ごとにrevisionを増やす', () async {
    final repository = MemoryMatchRepository();
    final controller = MatchController(repository, const ScoreRuleEngine());
    await controller.start(matchRecord());

    await controller.recordFault();
    expect(repository.record!.revision, 1);
    final eventID = await controller.addPoint(Side.mine);
    expect(repository.record!.revision, 2);
    await controller.setPointReason(eventID!, PointReason.serviceAce);
    expect(repository.record!.revision, 3);
    await controller.undo();
    expect(repository.record!.revision, 4);
  });

  test('Watch保存成功後だけ編集権をWatchへ移す', () async {
    final repository = MemoryMatchRepository();
    final gateway = FakeWatchSessionGateway();
    final controller = MatchController(
      repository,
      const ScoreRuleEngine(),
      watchGateway: gateway,
    );
    await controller.start(matchRecord());

    expect(await controller.handoffToWatch(), isTrue);
    expect(repository.record!.scoreInputOwner, ScoreInputOwner.watch);
    expect(repository.record!.revision, 1);
    expect(gateway.handedOff!.schemaVersion, 2);
    expect(gateway.handedOff!.match!.deuceEnabled, isTrue);
    expect(gateway.handedOff!.watchSessionId, isNotEmpty);
    expect(await controller.addPoint(Side.mine), isNull);
  });

  test('Watch引き渡し失敗時はiPhone編集を維持する', () async {
    final repository = MemoryMatchRepository();
    final gateway = FakeWatchSessionGateway()..acceptHandoff = false;
    final controller = MatchController(
      repository,
      const ScoreRuleEngine(),
      watchGateway: gateway,
    );
    await controller.start(matchRecord());

    expect(await controller.handoffToWatch(), isFalse);
    expect(repository.record!.scoreInputOwner, ScoreInputOwner.phone);
  });

  test('古いrevisionと異なるセッションを無視し、新しい状態だけ永続化する', () async {
    final repository = MemoryMatchRepository();
    final gateway = FakeWatchSessionGateway();
    final controller = MatchController(
      repository,
      const ScoreRuleEngine(),
      watchGateway: gateway,
    );
    await controller.start(matchRecord());
    await controller.handoffToWatch();
    final handedOff = repository.record!;

    WatchSyncEnvelope envelope(
      MatchRecord match,
      String messageId, {
      int schemaVersion = WatchSyncEnvelope.currentSchemaVersion,
    }) => WatchSyncEnvelope(
      schemaVersion: schemaVersion,
      messageId: messageId,
      type: WatchSyncMessageType.snapshot,
      matchId: match.id,
      watchSessionId: match.watchSessionId!,
      revision: match.revision,
      sentAt: DateTime(2026),
      match: match,
    );

    gateway.eventsController.add(envelope(handedOff, 'duplicate').asEvent());
    await Future<void>.delayed(Duration.zero);
    expect(gateway.acknowledged, isEmpty);

    final newer = handedOff.copyWith(revision: handedOff.revision + 1);
    gateway.eventsController.add(
      envelope(newer, 'legacy-schema', schemaVersion: 1).asEvent(),
    );
    await Future<void>.delayed(Duration.zero);
    expect(repository.record!.revision, handedOff.revision);
    expect(gateway.acknowledged, isEmpty);

    gateway.eventsController.add(WatchEnvelopeReceived(envelope(newer, 'new')));
    await Future<void>.delayed(Duration.zero);
    expect(repository.record!.revision, newer.revision);
    expect(gateway.acknowledged, ['new']);
  });

  test('同一revisionでも最新状態を確認してiPhoneへ編集権を戻せる', () async {
    final repository = MemoryMatchRepository();
    final gateway = FakeWatchSessionGateway();
    final controller = MatchController(
      repository,
      const ScoreRuleEngine(),
      watchGateway: gateway,
    );
    await controller.start(matchRecord());
    await controller.handoffToWatch();
    final watchRecord = repository.record!;
    gateway.phoneControlResponse = WatchSyncEnvelope(
      schemaVersion: WatchSyncEnvelope.currentSchemaVersion,
      messageId: 'return-control',
      type: WatchSyncMessageType.snapshot,
      matchId: watchRecord.id,
      watchSessionId: watchRecord.watchSessionId!,
      revision: watchRecord.revision,
      sentAt: DateTime(2026),
      match: watchRecord,
    );

    expect(await controller.requestPhoneControl(), isTrue);
    expect(repository.record!.scoreInputOwner, ScoreInputOwner.phone);
    expect(repository.record!.watchSessionId, isNull);
    expect(
      gateway.acknowledgedTypes,
      contains(WatchSyncMessageType.requestPhoneControl),
    );
  });
}

extension on WatchSyncEnvelope {
  WatchGatewayEvent asEvent() => WatchEnvelopeReceived(this);
}
