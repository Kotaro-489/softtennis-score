import Flutter
import Foundation
import WatchConnectivity

final class PhoneWatchConnectivityBridge: NSObject {
  static let shared = PhoneWatchConnectivityBridge()

  private let methodChannelName = "com.kotaro489.softtennisscore/watch"
  private let eventChannelName = "com.kotaro489.softtennisscore/watch/events"
  private let session: WCSession? = WCSession.isSupported() ? .default : nil
  private var eventSink: FlutterEventSink?
  private let pendingURL: URL

  private override init() {
    let base = try? FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    pendingURL = (base ?? FileManager.default.temporaryDirectory)
      .appendingPathComponent("pending-watch-envelope.json")
    super.init()
    session?.delegate = self
    session?.activate()
  }

  func attach(to messenger: FlutterBinaryMessenger) {
    let method = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
    method.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(self)
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      result(statusDictionary())
    case "handoffMatch":
      guard let payload = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_arguments", message: "同期データが不正です", details: nil))
        return
      }
      handoff(payload, result: result)
    case "requestPhoneControl":
      guard let arguments = call.arguments as? [String: Any],
            let sessionID = arguments["watchSessionId"] as? String else {
        result(FlutterError(code: "invalid_arguments", message: "セッションIDがありません", details: nil))
        return
      }
      requestPhoneControl(sessionID: sessionID, result: result)
    case "forcePhoneControl":
      guard let arguments = call.arguments as? [String: Any],
            let sessionID = arguments["watchSessionId"] as? String else {
        result(FlutterError(code: "invalid_arguments", message: "セッションIDがありません", details: nil))
        return
      }
      invalidate(sessionID: sessionID)
      sendControl(command: "forcePhoneControl", sessionID: sessionID)
      result(nil)
    case "drainPendingEnvelope":
      result(readPending())
    case "ackPersisted":
      guard let arguments = call.arguments as? [String: Any] else {
        result(FlutterError(code: "invalid_arguments", message: "ACKが不正です", details: nil))
        return
      }
      acknowledge(arguments)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handoff(_ payload: [String: Any], result: @escaping FlutterResult) {
    guard let session, session.activationState == .activated, session.isReachable else {
      result(false)
      return
    }
    session.sendMessage(payload) { reply in
      DispatchQueue.main.async { result(reply["accepted"] as? Bool ?? false) }
    } errorHandler: { _ in
      DispatchQueue.main.async { result(false) }
    }
  }

  private func requestPhoneControl(sessionID: String, result: @escaping FlutterResult) {
    guard let session, session.activationState == .activated, session.isReachable else {
      result(nil)
      return
    }
    session.sendMessage([
      "command": "requestPhoneControl",
      "watchSessionId": sessionID,
    ]) { [weak self] reply in
      guard reply["schemaVersion"] != nil, self?.persist(reply) == true else {
        DispatchQueue.main.async { result(nil) }
        return
      }
      DispatchQueue.main.async { result(reply) }
    } errorHandler: { _ in
      DispatchQueue.main.async { result(nil) }
    }
  }

  private func sendControl(command: String, sessionID: String) {
    guard let session else { return }
    let payload: [String: Any] = ["command": command, "watchSessionId": sessionID]
    for transfer in session.outstandingUserInfoTransfers { transfer.cancel() }
    try? session.updateApplicationContext(payload)
    session.transferUserInfo(payload)
    if session.isReachable { session.sendMessage(payload, replyHandler: nil) }
  }

  private func acknowledge(_ arguments: [String: Any]) {
    if let pending = readPending(),
       pending["messageId"] as? String == arguments["messageId"] as? String {
      try? FileManager.default.removeItem(at: pendingURL)
    }
    guard let sessionID = arguments["watchSessionId"] as? String,
          let revision = arguments["revision"] as? Int else { return }
    UserDefaults.standard.set(sessionID, forKey: "watchLastAckSessionID")
    UserDefaults.standard.set(revision, forKey: "watchLastAckRevision")
    if arguments["releaseControl"] as? Bool == true { invalidate(sessionID: sessionID) }
    let payload: [String: Any] = [
      "schemaVersion": 1,
      "messageId": UUID().uuidString,
      "type": "ack",
      "matchId": arguments["matchId"] as? String ?? "",
      "watchSessionId": sessionID,
      "revision": revision,
      "releaseControl": arguments["releaseControl"] as? Bool ?? false,
      "sentAt": Self.timestamp(),
      "match": NSNull(),
    ]
    session?.transferUserInfo(payload)
    if session?.isReachable == true { session?.sendMessage(payload, replyHandler: nil) }
  }

  private func receive(_ payload: [String: Any]) {
    guard payload["schemaVersion"] != nil, persist(payload) else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.eventSink?(["event": "envelope", "envelope": payload])
      self.eventSink?(["event": "status", "status": self.statusDictionary()])
    }
  }

  @discardableResult
  private func persist(_ payload: [String: Any]) -> Bool {
    do {
      if let sessionID = payload["watchSessionId"] as? String,
         invalidatedSessionIDs().contains(sessionID) {
        return false
      }
      if let sessionID = payload["watchSessionId"] as? String,
         sessionID == UserDefaults.standard.string(forKey: "watchLastAckSessionID"),
         let incomingRevision = payload["revision"] as? Int,
         incomingRevision <= UserDefaults.standard.integer(forKey: "watchLastAckRevision") {
        return false
      }
      if let existing = readPending(),
         existing["watchSessionId"] as? String == payload["watchSessionId"] as? String,
         let existingRevision = existing["revision"] as? Int,
         let incomingRevision = payload["revision"] as? Int,
         existingRevision > incomingRevision {
        return false
      }
      let data = try JSONSerialization.data(withJSONObject: payload)
      try data.write(to: pendingURL, options: .atomic)
      UserDefaults.standard.set(Date(), forKey: "watchLastSyncAt")
      return true
    } catch {
      return false
    }
  }

  private func readPending() -> [String: Any]? {
    guard let data = try? Data(contentsOf: pendingURL),
          let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return nil
    }
    return value
  }

  private func statusDictionary() -> [String: Any] {
    guard let session else {
      return ["supported": false, "paired": false, "appInstalled": false, "reachable": false]
    }
    var value: [String: Any] = [
      "supported": true,
      "paired": session.isPaired,
      "appInstalled": session.isWatchAppInstalled,
      "reachable": session.isReachable,
    ]
    if let lastSync = UserDefaults.standard.object(forKey: "watchLastSyncAt") as? Date {
      value["lastSyncAt"] = Self.timestamp(lastSync)
    }
    return value
  }

  private func invalidatedSessionIDs() -> Set<String> {
    Set(UserDefaults.standard.stringArray(forKey: "invalidatedWatchSessionIDs") ?? [])
  }

  private func invalidate(sessionID: String) {
    var values = invalidatedSessionIDs()
    values.insert(sessionID)
    UserDefaults.standard.set(Array(values.suffix(20)), forKey: "invalidatedWatchSessionIDs")
  }

  private static func timestamp(_ date: Date = Date()) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
}

extension PhoneWatchConnectivityBridge: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    events(["event": "status", "status": statusDictionary()])
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

extension PhoneWatchConnectivityBridge: WCSessionDelegate {
  func session(
    _ session: WCSession,
    activationDidCompleteWith activationState: WCSessionActivationState,
    error: Error?
  ) {
    emitStatus()
  }

  func sessionDidBecomeInactive(_ session: WCSession) { emitStatus() }

  func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
    emitStatus()
  }

  func sessionReachabilityDidChange(_ session: WCSession) { emitStatus() }
  func sessionWatchStateDidChange(_ session: WCSession) { emitStatus() }

  func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    receive(message)
  }

  func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
    receive(userInfo)
  }

  func session(
    _ session: WCSession,
    didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    receive(applicationContext)
  }

  private func emitStatus() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.eventSink?(["event": "status", "status": self.statusDictionary()])
    }
  }
}
