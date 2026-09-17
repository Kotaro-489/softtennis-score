import Foundation

struct ScoreSnapshotDTO: Equatable {
  let myGames: Int
  let opponentGames: Int
  let myPoints: Int
  let opponentPoints: Int
  let isFinalGame: Bool
  let isCompleted: Bool
  let servingSide: MatchSide
  let serverId: String
  let receiverId: String
  let shouldChangeSides: Bool
  let shouldChangeService: Bool
}

struct PointContextDTO {
  let servingSide: MatchSide
  let winningSide: MatchSide
  let serveAttempt: ServeAttemptDTO
}

struct SwiftScoreRuleEngine {
  func context(for eventID: String, in record: MatchRecordDTO) -> PointContextDTO? {
    guard let index = record.events.firstIndex(where: { $0.id == eventID }) else {
      return nil
    }
    var previous = record
    previous.events = Array(record.events.prefix(index))
    return PointContextDTO(
      servingSide: evaluate(previous).servingSide,
      winningSide: record.events[index].winningSide,
      serveAttempt: record.events[index].serveAttempt
    )
  }

  func evaluate(_ record: MatchRecordDTO) -> ScoreSnapshotDTO {
    var myGames = 0
    var opponentGames = 0
    var myPoints = 0
    var opponentPoints = 0
    var pointsInGame = 0
    var completed = false
    var changedSides = false
    var changedService = false

    for event in record.events where !completed {
      changedSides = false
      changedService = false
      pointsInGame += 1
      if event.winningSide == .mine { myPoints += 1 } else { opponentPoints += 1 }
      let finalGame = isFinal(record.format, myGames, opponentGames)
      if winsGame(record.deuceEnabled, myPoints, opponentPoints, finalGame) {
        if myPoints > opponentPoints { myGames += 1 } else { opponentGames += 1 }
        changedSides = !finalGame && (myGames + opponentGames).isMultiple(of: 2) == false
        changedService = true
        completed = myGames == record.format.gamesToWin || opponentGames == record.format.gamesToWin
        if !completed {
          myPoints = 0
          opponentPoints = 0
          pointsInGame = 0
        }
      }
      if finalGame && !completed {
        changedService = pointsInGame.isMultiple(of: 2)
        changedSides = pointsInGame == 2 || (pointsInGame > 2 && (pointsInGame - 2).isMultiple(of: 4))
      }
    }

    let finalGame = isFinal(record.format, myGames, opponentGames)
    let service = service(record, myGames + opponentGames, pointsInGame, finalGame)
    return ScoreSnapshotDTO(
      myGames: myGames,
      opponentGames: opponentGames,
      myPoints: myPoints,
      opponentPoints: opponentPoints,
      isFinalGame: finalGame,
      isCompleted: completed,
      servingSide: service.0,
      serverId: service.1,
      receiverId: service.2,
      shouldChangeSides: changedSides,
      shouldChangeService: changedService
    )
  }

  private func isFinal(_ format: MatchFormatDTO, _ mine: Int, _ opponent: Int) -> Bool {
    mine == format.maximumGames / 2 && opponent == format.maximumGames / 2
  }

  private func winsGame(
    _ deuceEnabled: Bool,
    _ mine: Int,
    _ opponent: Int,
    _ finalGame: Bool
  ) -> Bool {
    let target = finalGame ? 7 : 4
    let high = max(mine, opponent)
    return high >= target && (!deuceEnabled || abs(mine - opponent) >= 2)
  }

  private func service(
    _ record: MatchRecordDTO,
    _ completedGames: Int,
    _ pointIndex: Int,
    _ finalGame: Bool
  ) -> (MatchSide, String, String) {
    let serviceBlock = pointIndex / 2
    let servingSide: MatchSide
    if finalGame {
      servingSide = serviceBlock.isMultiple(of: 2) ? record.firstServingSide : record.firstServingSide.other
    } else {
      servingSide = completedGames.isMultiple(of: 2) ? record.firstServingSide : record.firstServingSide.other
    }
    let servingPair = servingSide == .mine ? record.myPair : record.opponentPair
    let receivingPair = servingSide == .mine ? record.opponentPair : record.myPair
    let initialServer = servingSide == record.firstServingSide ? record.firstServerId : record.firstReceiverId
    let initialReceiver = servingSide == record.firstServingSide ? record.firstReceiverId : record.firstServerId
    let serverRotation = finalGame ? serviceBlock / 2 : pointIndex / 2
    return (
      servingSide,
      alternate(servingPair, initialServer, serverRotation),
      alternate(receivingPair, initialReceiver, pointIndex)
    )
  }

  private func alternate(_ pair: PairDTO, _ preferredID: String, _ index: Int) -> String {
    let base = pair.players.firstIndex(where: { $0.id == preferredID }) ?? 0
    return pair.players[(base + index) % pair.players.count].id
  }
}

struct SwiftPointReasonPolicy {
  func availableReasons(
    servingSide: MatchSide,
    winningSide: MatchSide,
    serveAttempt: ServeAttemptDTO
  ) -> [PointReasonDTO] {
    var reasons: [PointReasonDTO] = [.rallyWinner, .opponentNet, .opponentOut, .other]
    if winningSide == servingSide {
      reasons.insert(.serviceAce, at: 0)
    } else {
      reasons.insert(.returnAce, at: 0)
      if serveAttempt == .second { reasons.insert(.opponentDoubleFault, at: 1) }
    }
    return reasons
  }
}
