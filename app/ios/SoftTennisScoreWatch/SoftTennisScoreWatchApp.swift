import SwiftUI

@MainActor
final class WatchAppModel {
  let store: WatchMatchStore
  let connectivity: WatchConnectivityService

  init() {
    let store = WatchMatchStore()
    self.store = store
    connectivity = WatchConnectivityService(store: store)
    store.onSnapshot = { [weak connectivity] _ in connectivity?.sendLatestSnapshot() }
    connectivity.sendLatestSnapshot()
  }
}

@main
struct SoftTennisScoreWatchApp: App {
  @State private var model = WatchAppModel()

  var body: some Scene {
    WindowGroup {
      WatchContentView(store: model.store, connectivity: model.connectivity)
    }
  }
}
