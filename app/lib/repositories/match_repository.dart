import '../models/match_models.dart';

abstract class MatchRepository {
  Future<void> save(MatchRecord record);
  Future<MatchRecord?> findInProgress();
  Future<List<MatchRecord>> findCompleted();
  Future<void> delete(String id);
  Future<MyPairProfile?> loadMyPairProfile();
  Future<void> saveMyPairProfile(MyPairProfile profile);
}
