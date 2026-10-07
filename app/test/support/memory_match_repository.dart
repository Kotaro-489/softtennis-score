import 'dart:async';

import 'package:softtennis_score/models/match_models.dart';
import 'package:softtennis_score/repositories/match_repository.dart';

class MemoryMatchRepository implements MatchRepository {
  MemoryMatchRepository({this.record});

  MatchRecord? record;
  MyPairProfile? profile;
  Completer<void>? saveGate;
  Object? saveError;

  @override
  Future<void> delete(String id) async {
    if (record?.id == id) record = null;
  }

  @override
  Future<List<MatchRecord>> findCompleted() async =>
      record?.completedAt == null ? [] : [record!];

  @override
  Future<MatchRecord?> findInProgress() async =>
      record?.completedAt == null ? record : null;

  @override
  Future<MyPairProfile?> loadMyPairProfile() async => profile;

  /// 保存待ち・失敗を再現し、成功したレコードだけを後続の読み込みへ返す。
  @override
  Future<void> save(MatchRecord value) async {
    await saveGate?.future;
    if (saveError case final error?) throw error;
    record = value;
  }

  @override
  Future<void> saveMyPairProfile(MyPairProfile value) async => profile = value;
}
