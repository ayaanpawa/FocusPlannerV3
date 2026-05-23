import SwiftUI

@main
struct FocusPlannerApp: App {
    @StateObject private var store = PlannerStore.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .environmentObject(store)
                #if os(macOS)
                .frame(minWidth: 1000, idealWidth: 1200, minHeight: 700, idealHeight: 800)
                #endif
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentMinSize)
        .windowToolbarStyle(.unified)
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await store.fetchIfNeeded() }
            }
        }

        #if os(macOS)
        // ⌘, opens Settings in its own window on macOS
        Settings {
            SettingsView()
                .environmentObject(store)
                .frame(width: 480, height: 620)
        }

        // Menu-bar dropdown — quick glance at today / tomorrow / upcoming
        MenuBarExtra("FocusPlanner", systemImage: "calendar") {
            MenuBarView()
                .environmentObject(store)
        }
        .menuBarExtraStyle(.window)
        #endif
    }
}
