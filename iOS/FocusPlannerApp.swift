import SwiftUI

@main
struct FocusPlannerApp: App {
    @StateObject private var store = PlannerStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await store.fetchIfNeeded() }
            }
        }
    }
}
