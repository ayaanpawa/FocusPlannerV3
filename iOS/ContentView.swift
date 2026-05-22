import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var showSettings = false
    @State private var selectedTab   = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MonthView()
                .tabItem { Label("Month",    systemImage: "calendar") }
                .tag(0)

            HomeworkView()
                .tabItem { Label("Homework", systemImage: "checklist") }
                .tag(1)

            TestsView()
                .tabItem { Label("Tests",    systemImage: "doc.text.fill") }
                .tag(2)

            ClassesTabView()
                .tabItem { Label("Classes",  systemImage: "books.vertical.fill") }
                .tag(3)
        }
        .overlay(alignment: .topTrailing) {
            // Global settings gear — visible on all tabs
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
            .padding(.top, 8)
            .padding(.trailing, 4)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .onAppear {
            // First-launch: if no token, open settings
            if KeychainHelper.loadToken() == nil {
                showSettings = true
            } else {
                Task { await store.fetch() }
            }
        }
    }
}
