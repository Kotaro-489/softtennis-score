import Foundation

enum MatchSide: String, Codable {
  case mine
  case opponent

  var other: MatchSide { self == .mine ? .opponent : .mine }
}

enum ServeAttemptDTO: String, Codable {
  case first
  case second
}

enum ScoreInputOwnerDTO: String, Codable {
  case phone
  case watch
}

enum MatchFormatDTO: String, Codable {
  case officialFive
  case officialSeven
  case generalNine
  case practiceThree

  var maximumGames: Int {
    switch self {
    case .officialFive: return 5
    case .officialSeven: return 7
    case .generalNine: return 9
    case .practiceThree: return 3
    }
  }

  var gamesToWin: Int { maximumGames / 2 + 1 }
  var isNoAd: Bool { self == .practiceThree }
}

enum PointReasonDTO: String, Codable, CaseIterable, Identifiable {
  case serviceAce
  case returnAce
  case rallyWinner
  case opponentNet
  case opponentOut
  case opponentDoubleFault
  case other

  var id: String { rawValue }

  var label: String {
    switch self {
    case .serviceAce: return "サービスエース"
    case .returnAce: return "リターンエース"
    case .rallyWinner: return "ラリーウィナー"
    case .opponentNet: return "相手のネット"
    case .opponentOut: return "相手のアウト"
    case .opponentDoubleFault: return "相手のダブルフォルト"
    case .other: return "その他"
    }
  }
}

struct PlayerDTO: Codable, Equatable, Identifiable {
  let id: String
  let name: String
}

struct PairDTO: Codable, Equatable, Identifiable {
  let id: String
  let name: String
  let players: [PlayerDTO]
}

struct PointEventDTO: Codable, Equatable, Identifiable {
  let id: String
  let winningSide: MatchSide
  let createdAt: String
  let serveAttempt: ServeAttemptDTO
  var reason: PointReasonDTO?
}

struct MatchRecordDTO: Codable, Equatable, Identifiable {
  let id: String
  let myPair: PairDTO
  let opponentPair: PairDTO
  let format: MatchFormatDTO
  let firstServingSide: MatchSide
  let firstServerId: String
  let firstReceiverId: String
  let createdAt: String
  var currentServeAttempt: ServeAttemptDTO
  var scoreInputOwner: ScoreInputOwnerDTO
  var revision: Int
  var watchSessionId: String?
  var completedAt: String?
  var events: [PointEventDTO]

  enum CodingKeys: String, CodingKey {
    case id, myPair, opponentPair, format, firstServingSide
    case firstServerId, firstReceiverId, createdAt, currentServeAttempt
    case scoreInputOwner, revision, watchSessionId, completedAt, events
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    myPair = try container.decode(PairDTO.self, forKey: .myPair)
    opponentPair = try container.decode(PairDTO.self, forKey: .opponentPair)
    format = try container.decode(MatchFormatDTO.self, forKey: .format)
    firstServingSide = try container.decode(MatchSide.self, forKey: .firstServingSide)
    firstServerId = try container.decode(String.self, forKey: .firstServerId)
    firstReceiverId = try container.decode(String.self, forKey: .firstReceiverId)
    createdAt = try container.decode(String.self, forKey: .createdAt)
    currentServeAttempt = try container.decodeIfPresent(
      ServeAttemptDTO.self,
      forKey: .currentServeAttempt
    ) ?? .first
    scoreInputOwner = try container.decodeIfPresent(
      ScoreInputOwnerDTO.self,
      forKey: .scoreInputOwner
    ) ?? .phone
    revision = try container.decodeIfPresent(Int.self, forKey: .revision) ?? 0
    watchSessionId = try container.decodeIfPresent(String.self, forKey: .watchSessionId)
    completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
    events = try container.decodeIfPresent([PointEventDTO].self, forKey: .events) ?? []
  }

  init(
    id: String,
    myPair: PairDTO,
    opponentPair: PairDTO,
    format: MatchFormatDTO,
    firstServingSide: MatchSide,
    firstServerId: String,
    firstReceiverId: String,
    createdAt: String,
    currentServeAttempt: ServeAttemptDTO = .first,
    scoreInputOwner: ScoreInputOwnerDTO = .phone,
    revision: Int = 0,
    watchSessionId: String? = nil,
    completedAt: String? = nil,
    events: [PointEventDTO] = []
  ) {
    self.id = id
    self.myPair = myPair
    self.opponentPair = opponentPair
    self.format = format
    self.firstServingSide = firstServingSide
    self.firstServerId = firstServerId
    self.firstReceiverId = firstReceiverId
    self.createdAt = createdAt
    self.currentServeAttempt = currentServeAttempt
    self.scoreInputOwner = scoreInputOwner
    self.revision = revision
    self.watchSessionId = watchSessionId
    self.completedAt = completedAt
    self.events = events
  }
}

enum WatchSyncMessageTypeDTO: String, Codable {
  case handoff
  case snapshot
  case requestPhoneControl
  case ack
}

struct WatchSyncEnvelopeDTO: Codable, Equatable {
  static let currentSchemaVersion = 1

  let schemaVersion: Int
  let messageId: String
  let type: WatchSyncMessageTypeDTO
  let matchId: String
  let watchSessionId: String
  let revision: Int
  let sentAt: String
  let match: MatchRecordDTO?

  func dictionary() throws -> [String: Any] {
    let data = try JSONEncoder().encode(self)
    return try JSONSerialization.jsonObject(with: data) as! [String: Any]
  }

  static func decode(dictionary: [String: Any]) throws -> WatchSyncEnvelopeDTO {
    let data = try JSONSerialization.data(withJSONObject: dictionary)
    return try JSONDecoder().decode(WatchSyncEnvelopeDTO.self, from: data)
  }
}

enum SharedClock {
  static func now() -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: Date())
  }
}
