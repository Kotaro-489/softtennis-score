import '../models/match_models.dart';

/// ポイントのサービス状況と勝者に整合する得点理由を返す。
class PointReasonPolicy {
  const PointReasonPolicy();

  List<PointReason> availableReasons({
    required Side servingSide,
    required Side winningSide,
    required ServeAttempt serveAttempt,
  }) => PointReason.values
      .where((reason) {
        if (reason == PointReason.serviceAce) {
          return winningSide == servingSide;
        }
        if (reason == PointReason.returnAce) {
          return winningSide != servingSide;
        }
        if (reason == PointReason.opponentDoubleFault) {
          return winningSide != servingSide &&
              serveAttempt == ServeAttempt.second;
        }
        return true;
      })
      .toList(growable: false);

  bool isAllowed({
    required PointReason reason,
    required Side servingSide,
    required Side winningSide,
    required ServeAttempt serveAttempt,
  }) => availableReasons(
    servingSide: servingSide,
    winningSide: winningSide,
    serveAttempt: serveAttempt,
  ).contains(reason);
}
