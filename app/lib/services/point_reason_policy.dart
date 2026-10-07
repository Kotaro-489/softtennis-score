import '../models/match_models.dart';

class PointReasonPolicy {
  const PointReasonPolicy();

  /// サービス状況と得点側に整合する理由を、画面の表示順で返す。
  List<PointReason> availableReasons({
    required Side servingSide,
    required Side winningSide,
    required ServeAttempt serveAttempt,
  }) => PointReason.values
      .where(
        (reason) => isAllowed(
          reason: reason,
          servingSide: servingSide,
          winningSide: winningSide,
          serveAttempt: serveAttempt,
        ),
      )
      .toList(growable: false);

  bool isAllowed({
    required PointReason reason,
    required Side servingSide,
    required Side winningSide,
    required ServeAttempt serveAttempt,
  }) => switch (reason) {
    PointReason.serviceAce => winningSide == servingSide,
    PointReason.returnAce => winningSide != servingSide,
    PointReason.opponentDoubleFault =>
      winningSide != servingSide && serveAttempt == ServeAttempt.second,
    _ => true,
  };
}
