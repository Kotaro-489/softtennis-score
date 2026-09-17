import XCTest
@testable import SoftTennisScoreWatch

final class ScoreRuleEngineTests: XCTestCase {
  func testSharedRuleVectors() throws {
    let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "rule_vectors", withExtension: "json"))
    let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [[String: Any]]

    for vector in raw {
      let format = MatchFormatDTO(rawValue: vector["format"] as! String)!
      let winners = (vector["winners"] as! [String]).map { MatchSide(rawValue: $0)! }
      let expected = vector["expected"] as! [String: Any]
      let actual = SwiftScoreRuleEngine().evaluate(record(format: format, winners: winners))

      XCTAssertEqual(actual.myGames, expected["myGames"] as? Int, vector["name"] as! String)
      XCTAssertEqual(actual.opponentGames, expected["opponentGames"] as? Int)
      XCTAssertEqual(actual.myPoints, expected["myPoints"] as? Int)
      XCTAssertEqual(actual.opponentPoints, expected["opponentPoints"] as? Int)
      XCTAssertEqual(actual.servingSide.rawValue, expected["servingSide"] as? String)
      XCTAssertEqual(actual.serverId, expected["serverId"] as? String)
      XCTAssertEqual(actual.receiverId, expected["receiverId"] as? String)
      XCTAssertEqual(actual.shouldChangeSides, expected["shouldChangeSides"] as? Bool)
      XCTAssertEqual(actual.shouldChangeService, expected["shouldChangeService"] as? Bool)
      XCTAssertEqual(actual.isCompleted, expected["isCompleted"] as? Bool)
    }
  }

  func testReasonPolicyUsesServeAttempt() {
    let policy = SwiftPointReasonPolicy()
    XCTAssertEqual(
      policy.availableReasons(servingSide: .mine, winningSide: .mine, serveAttempt: .first).first,
      .serviceAce
    )
    XCTAssertTrue(
      policy.availableReasons(servingSide: .mine, winningSide: .opponent, serveAttempt: .second)
        .contains(.opponentDoubleFault)
    )
  }

  @MainActor
  func testOfflineStorePersistsEveryOperationAndRestoresSecondServe() throws {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("match.json")
    let store = WatchMatchStore(fileURL: file)
    let match = record(format: .officialFive, winners: [])
    let watchMatch = MatchRecordDTO(
      id: match.id,
      myPair: match.myPair,
      opponentPair: match.opponentPair,
      format: match.format,
      firstServingSide: match.firstServingSide,
      firstServerId: match.firstServerId,
      firstReceiverId: match.firstReceiverId,
      createdAt: match.createdAt,
      scoreInputOwner: .watch,
      revision: 1,
      watchSessionId: "watch-1"
    )
    let envelope = WatchSyncEnvelopeDTO(
      schemaVersion: 1,
      messageId: "handoff",
      type: .handoff,
      matchId: watchMatch.id,
      watchSessionId: "watch-1",
      revision: 1,
      sentAt: SharedClock.now(),
      match: watchMatch
    )

    XCTAssertTrue(store.acceptHandoff(envelope))
    store.fault()
    XCTAssertEqual(store.record?.currentServeAttempt, .second)

    let restored = WatchMatchStore(fileURL: file)
    XCTAssertEqual(restored.record?.currentServeAttempt, .second)
    XCTAssertEqual(restored.record?.revision, 2)
  }

  @MainActor
  func testSecondServePointHasTwoStepUndo() {
    let file = FileManager.default.temporaryDirectory
      .appendingPathComponent("\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    let store = WatchMatchStore(fileURL: file)
    var match = record(format: .officialFive, winners: [])
    match.scoreInputOwner = .watch
    match.watchSessionId = "watch-1"
    let envelope = WatchSyncEnvelopeDTO(
      schemaVersion: 1,
      messageId: "handoff",
      type: .handoff,
      matchId: match.id,
      watchSessionId: "watch-1",
      revision: 0,
      sentAt: SharedClock.now(),
      match: match
    )
    XCTAssertTrue(store.acceptHandoff(envelope))

    store.fault()
    store.addPoint(.mine)
    store.undo()
    XCTAssertEqual(store.record?.events.count, 0)
    XCTAssertEqual(store.record?.currentServeAttempt, .second)
    store.undo()
    XCTAssertEqual(store.record?.currentServeAttempt, .first)
  }

  private func record(format: MatchFormatDTO, winners: [MatchSide]) -> MatchRecordDTO {
    MatchRecordDTO(
      id: "vector",
      myPair: PairDTO(id: "mine", name: "自分", players: [
        PlayerDTO(id: "m1", name: "A"), PlayerDTO(id: "m2", name: "B"),
      ]),
      opponentPair: PairDTO(id: "opponent", name: "相手", players: [
        PlayerDTO(id: "o1", name: "C"), PlayerDTO(id: "o2", name: "D"),
      ]),
      format: format,
      firstServingSide: .mine,
      firstServerId: "m1",
      firstReceiverId: "o1",
      createdAt: "2026-01-01T00:00:00Z",
      events: winners.enumerated().map {
        PointEventDTO(
          id: String($0.offset),
          winningSide: $0.element,
          createdAt: "2026-01-01T00:00:00Z",
          serveAttempt: .first,
          reason: nil
        )
      }
    )
  }
}
