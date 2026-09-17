import Combine
import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
  @Published private(set) var reachable = false
  private let store: WatchMatchStore
  private let session: WCSession?

  init(store: WatchMatchStore, session: WCSession? = WCSession.isSupported() ? .default : nil) {
    self.store = store
    self.session = session
    super.init()
    session?.delegate = self
    session?.activate()
  }

  func sendLatestSnapshot() {
    guard let session, let envelope = store.latestEnvelope(), let payload = try? envelope.dictionary() else {
      return
    }
    for transfer in session.outstandingUserInfoTransfers { transfer.cancel() }
    try? session.updateApplicationContext(payload)
    session.transferUserInfo(payload)
    if session.isReachable { session.sendMessage(payload, replyHandler: nil) }
  }

  private func receive(_ payload: [String: Any], reply: (([String: Any]) -> Void)? = nil) {
    if payload["command"] as? String == "requestPhoneControl" {
      guard
        let requestedSession = payload["watchSessionId"] as? String,
        requestedSession == store.record?.watchSessionId,
        let envelope = store.latestEnvelope(),
        let dictionary = try? envelope.dictionary()
      else {
        reply?(["accepted": false])
        return
      }
      reply?(dictionary)
      return
    }
    if payload["command"] as? String == "forcePhoneControl",
       let sessionID = payload["watchSessionId"] as? String {
      store.invalidate(sessionID: sessionID)
      reply?(["accepted": true])
      return
    }
    if payload["type"] as? String == WatchSyncMessageTypeDTO.ack.rawValue,
       let sessionID = payload["watchSessionId"] as? String,
       let revision = payload["revision"] as? Int {
      store.acceptPersistedAck(
        sessionID: sessionID,
        revision: revision,
        releaseControl: payload["releaseControl"] as? Bool ?? false
      )
      reply?(["accepted": true])
      return
    }
    guard let envelope = try? WatchSyncEnvelopeDTO.decode(dictionary: payload) else {
      reply?(["accepted": false])
      return
    }
    reply?(["accepted": store.acceptHandoff(envelope)])
  }
}

extension WatchConnectivityService: WCSessionDelegate {
  nonisolated func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      self.reachable = session.isReachable
      if session.isReachable { self.sendLatestSnapshot() }
    }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in
      self.reachable = session.isReachable
      if session.isReachable { self.sendLatestSnapshot() }
    }
  }

  nonisolated func session(
    _ session: WCSession,
    didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    Task { @MainActor in self.receive(message, reply: replyHandler) }
  }

  nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    Task { @MainActor in self.receive(message) }
  }

  nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    Task { @MainActor in self.receive(userInfo) }
  }

  nonisolated func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    Task { @MainActor in self.receive(applicationContext) }
  }
}
