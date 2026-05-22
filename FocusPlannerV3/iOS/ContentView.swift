import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: PlannerStore
    @State private var showSettings   = false
    @State private var showOnboarding = false

    var body: some View {
        TabView(selection: $store.activeTab) {
            MonthView()
                .tabItem { Label("Month",    systemImage: "calendar") }
                .tag(0)

            DayView()
                .tabItem { Label("Day",      systemImage: "sun.max.fill") }
                .tag(1)

            HomeworkView()
                .tabItem { Label("Homework", systemImage: "checklist") }
                .tag(2)

            TestsView()
                .tabItem { Label("Tests",    systemImage: "doc.text.fill") }
                .tag(3)

            ClassesTabView()
                .tabItem { Label("Courses",  systemImage: "books.vertical.fill") }
                .tag(4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBg)
        .creamWindow(Color.fpBg)        // cream title bar on macOS
        .preferredColorScheme(.light)   // editorial cream theme is light-only
        .tint(Color.fpAccent)
        #if os(iOS)
        // iOS gets a floating gear button — macOS uses the Settings scene (⌘,)
        .overlay(alignment: .topTrailing) {
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
        #endif
        .sheet(isPresented: $showOnboarding) {
            OnboardingView()
                .environmentObject(store)
        }
        .onAppear {
            if !AppSettings.isConfigured {
                showOnboarding = true
            } else {
                Task { await store.fetch() }
            }
        }
    }
}
