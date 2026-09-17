import SwiftUI

struct WatchContentView: View {
  @ObservedObject var store: WatchMatchStore
  @ObservedObject var connectivity: WatchConnectivityService

  var body: some View {
    ZStack {
      if let record = store.record, let score = store.snapshot {
        scoreView(record: record, score: score)
      } else {
        VStack(spacing: 8) {
          Image(systemName: "iphone.and.arrow.forward")
            .font(.title2)
          Text("iPhoneで試合を作成し\n「Watchで記録」を押してください")
            .font(.footnote)
            .multilineTextAlignment(.center)
          Label(connectivity.reachable ? "接続中" : "接続待ち", systemImage: connectivity.reachable ? "checkmark.circle" : "wifi.slash")
            .font(.caption2)
        }
      }

      if let notice = store.notice {
        Color.black.opacity(0.92).ignoresSafeArea()
        VStack(spacing: 12) {
          Image(systemName: notice == .matchCompleted ? "trophy.fill" : "arrow.triangle.2.circlepath")
            .font(.largeTitle)
          Text(notice.rawValue).font(.headline)
          Button("続ける") { store.dismissNotice() }
            .frame(minHeight: 44)
        }
        .padding(8)
      }
    }
    .sheet(isPresented: $store.showingReasons) {
      reasonView
    }
  }

  private func scoreView(record: MatchRecordDTO, score: ScoreSnapshotDTO) -> some View {
    VStack(spacing: 2) {
      HStack(spacing: 3) {
        Button(action: store.undo) { Image(systemName: "arrow.uturn.backward") }
          .buttonStyle(.plain)
          .disabled(!store.canEdit)
          .accessibilityLabel("直前の操作を取り消す")
        Spacer(minLength: 2)
        Text("G \(score.myGames)–\(score.opponentGames)")
          .font(.caption.bold())
        Image(systemName: connectivity.reachable ? "checkmark.icloud" : "icloud.slash")
          .font(.caption2)
          .accessibilityLabel(connectivity.reachable ? "iPhoneと接続中" : "オフライン保存中")
        Spacer(minLength: 2)
        Button { store.showingReasons = true } label: { Text("理由").font(.caption2) }
          .buttonStyle(.plain)
          .disabled(!store.canEdit || !store.lastPointCanHaveReason)
      }
      .frame(height: 22)

      Text("\(score.myPoints) – \(score.opponentPoints)")
        .font(.system(size: 38, weight: .bold, design: .rounded))
        .minimumScaleFactor(0.7)
        .frame(maxHeight: 43)
        .accessibilityLabel("ポイント 自分 \(score.myPoints)、相手 \(score.opponentPoints)")

      Text(serveLabel(record: record, score: score))
        .font(.caption2.bold())
        .lineLimit(1)
        .minimumScaleFactor(0.65)
        .accessibilityLabel(fullServeLabel(record: record, score: score))

      HStack(spacing: 5) {
        scoreButton("自分 +1", side: .mine)
        scoreButton("相手 +1", side: .opponent)
      }

      Button(record.currentServeAttempt == .first ? "フォルト → 2nd" : "フォルト → 相手 +1") {
        store.fault()
      }
      .font(.caption.bold())
      .frame(maxWidth: .infinity, minHeight: 44)
      .disabled(!store.canEdit)
      .buttonStyle(.bordered)
    }
    .padding(.horizontal, 4)
  }

  private func scoreButton(_ title: String, side: MatchSide) -> some View {
    Button(title) { store.addPoint(side) }
      .font(.caption.bold())
      .frame(maxWidth: .infinity, minHeight: 44)
      .disabled(!store.canEdit)
      .buttonStyle(.borderedProminent)
  }

  private var reasonView: some View {
    List(store.availableReasons) { reason in
      Button(reason.label) { store.setReason(reason) }
    }
    .navigationTitle("得点理由")
  }

  private func serveLabel(record: MatchRecordDTO, score: ScoreSnapshotDTO) -> String {
    let shortName = playerName(id: score.serverId, record: record)
    let attempt = record.currentServeAttempt == .first ? "1st" : "2nd"
    return "\(score.servingSide == .mine ? "自分" : "相手")・\(attempt)・\(shortName)"
  }

  private func fullServeLabel(record: MatchRecordDTO, score: ScoreSnapshotDTO) -> String {
    let attempt = record.currentServeAttempt == .first ? "ファーストサービス" : "セカンドサービス"
    return "\(score.servingSide == .mine ? "自分" : "相手")、\(attempt)、サーバー \(playerName(id: score.serverId, record: record))"
  }

  private func playerName(id: String, record: MatchRecordDTO) -> String {
    (record.myPair.players + record.opponentPair.players).first(where: { $0.id == id })?.name ?? ""
  }
}
