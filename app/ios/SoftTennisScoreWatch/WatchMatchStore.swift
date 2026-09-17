import Combine
import Foundation
import WatchKit

enum WatchMatchNotice: String, Identifiable {
  case changeSides = "チェンジサイズ"
  case changeService = "チェンジサービス"
  case matchCompleted = "試合終了"

  var id: String { rawValue }
}

@MainActor
final class WatchMatchStore: ObservableObject {
  @Published private(set) var record: MatchRecordDTO?
  @Published private(set) var isSaving = false
  @Published var notice: WatchMatchNotice?
  @Published var showingReasons = false

  var onSnapshot: ((MatchRecordDTO) -> Void)?
  private let engine = SwiftScoreRuleEngine()
  private let reasonPolicy = SwiftPointReasonPolicy()
  private let fileURL: URL

  init(fileManager: FileManager = .default) {
    let base = try? fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    fileURL = (base ?? fileManager.temporaryDirectory)
      .appendingPathComponent("active-watch-match.json")
    record = try? Self.read(from: fileURL)
  }

  init(fileURL: URL) {
    self.fileURL = fileURL
    record = try? Self.read(from: fileURL)
  }

  var snapshot: ScoreSnapshotDTO? { record.map(engine.evaluate) }

  var canEdit: Bool {
    record?.scoreInputOwner == .watch && record?.completedAt == nil && !isSaving && notice == nil
  }

  var lastPointCanHaveReason: Bool {
    guard let event = record?.events.last else { return false }
    return event.reason != .opponentDoubleFault
  }

  var availableReasons: [PointReasonDTO] {
    guard
      let match = record,
      let event = match.events.last,
      event.reason != .opponentDoubleFault,
      let context = engine.context(for: event.id, in: match)
    else { return [] }
    return reasonPolicy.availableReasons(
      servingSide: context.servingSide,
      winningSide: context.winningSide,
      serveAttempt: context.serveAttempt
    )
  }

  func acceptHandoff(_ envelope: WatchSyncEnvelopeDTO) -> Bool {
    guard
      envelope.schemaVersion == WatchSyncEnvelopeDTO.currentSchemaVersion,
      envelope.type == .handoff,
      let incoming = envelope.match,
      incoming.id == envelope.matchId,
      incoming.watchSessionId == envelope.watchSessionId,
      incoming.revision == envelope.revision,
      incoming.scoreInputOwner == .watch
    else { return false }

    if let current = record,
       current.watchSessionId == incoming.watchSessionId,
       current.revision > incoming.revision {
      return false
    }
    return persistAndPublish(incoming, haptic: .start)
  }

  func addPoint(_ side: MatchSide) {
    guard canEdit else { return }
    update(haptic: .click) { match in
      match.events.append(
        PointEventDTO(
          id: UUID().uuidString,
          winningSide: side,
          createdAt: SharedClock.now(),
          serveAttempt: match.currentServeAttempt,
          reason: nil
        )
      )
      match.currentServeAttempt = .first
      match.revision += 1
      if engine.evaluate(match).isCompleted { match.completedAt = SharedClock.now() }
    }
  }

  func fault() {
    guard canEdit, let match = record else { return }
    if match.currentServeAttempt == .first {
      update(haptic: .directionUp) { value in
        value.currentServeAttempt = .second
        value.revision += 1
      }
      return
    }
    let receivingSide = engine.evaluate(match).servingSide.other
    update(haptic: .failure) { value in
      value.events.append(
        PointEventDTO(
          id: UUID().uuidString,
          winningSide: receivingSide,
          createdAt: SharedClock.now(),
          serveAttempt: .second,
          reason: .opponentDoubleFault
        )
      )
      value.currentServeAttempt = .first
      value.revision += 1
      if engine.evaluate(value).isCompleted { value.completedAt = SharedClock.now() }
    }
  }

  func undo() {
    guard canEdit, let match = record else { return }
    if match.currentServeAttempt == .first && match.events.isEmpty { return }
    update(haptic: .retry) { value in
      if value.currentServeAttempt == .second {
        value.currentServeAttempt = .first
      } else if let removed = value.events.popLast() {
        value.currentServeAttempt = removed.serveAttempt
        value.completedAt = nil
      }
      value.revision += 1
    }
  }

  func setReason(_ reason: PointReasonDTO) {
    guard canEdit, let event = record?.events.last, event.reason != .opponentDoubleFault else {
      return
    }
    guard availableReasons.contains(reason) else { return }
    update(haptic: .click) { value in
      guard !value.events.isEmpty else { return }
      value.events[value.events.count - 1].reason = reason
      value.revision += 1
    }
    showingReasons = false
  }

  func dismissNotice() { notice = nil }

  func latestEnvelope(type: WatchSyncMessageTypeDTO = .snapshot) -> WatchSyncEnvelopeDTO? {
    guard let match = record, let sessionID = match.watchSessionId else { return nil }
    return WatchSyncEnvelopeDTO(
      schemaVersion: WatchSyncEnvelopeDTO.currentSchemaVersion,
      messageId: UUID().uuidString,
      type: type,
      matchId: match.id,
      watchSessionId: sessionID,
      revision: match.revision,
      sentAt: SharedClock.now(),
      match: match
    )
  }

  func acceptPersistedAck(sessionID: String, revision: Int, releaseControl: Bool) {
    guard let match = record,
          match.watchSessionId == sessionID,
          revision >= match.revision,
          releaseControl || match.completedAt != nil else { return }
    try? FileManager.default.removeItem(at: fileURL)
    if releaseControl { record = nil }
  }

  func invalidate(sessionID: String) {
    guard record?.watchSessionId == sessionID else { return }
    try? FileManager.default.removeItem(at: fileURL)
    record = nil
  }

  private func update(
    haptic: WKHapticType,
    mutation: (inout MatchRecordDTO) -> Void
  ) {
    guard var updated = record else { return }
    let previous = engine.evaluate(updated)
    mutation(&updated)
    let next = engine.evaluate(updated)
    guard persistAndPublish(updated, haptic: haptic) else { return }

    if next.isCompleted && !previous.isCompleted {
      notice = .matchCompleted
      WKInterfaceDevice.current().play(.success)
    } else if next.shouldChangeSides {
      notice = .changeSides
      WKInterfaceDevice.current().play(.notification)
    } else if next.shouldChangeService {
      notice = .changeService
      WKInterfaceDevice.current().play(.directionUp)
    }
  }

  @discardableResult
  private func persistAndPublish(_ updated: MatchRecordDTO, haptic: WKHapticType) -> Bool {
    isSaving = true
    defer { isSaving = false }
    do {
      let data = try JSONEncoder().encode(updated)
      try data.write(to: fileURL, options: .atomic)
      record = updated
      WKInterfaceDevice.current().play(haptic)
      onSnapshot?(updated)
      return true
    } catch {
      WKInterfaceDevice.current().play(.failure)
      return false
    }
  }

  private static func read(from url: URL) throws -> MatchRecordDTO {
    try JSONDecoder().decode(MatchRecordDTO.self, from: Data(contentsOf: url))
  }
}
