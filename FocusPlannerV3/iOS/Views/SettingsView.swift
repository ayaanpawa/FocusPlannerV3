import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss

    @State private var schoolHost  = ""
    @State private var tokenText   = ""
    @State private var showToken   = false
    @State private var isRefreshing = false
    @State private var savedToast   = false
    @State private var confirmSignOut = false

    /// Replace this URL with wherever you host your real privacy policy.
    private let privacyPolicyURL = URL(string: "https://example.com/focusplanner-privacy")!

    var body: some View {
        NavigationStack {
            Form {
                canvasSection
                howToSection
                syncSection
                aboutSection
                signOutSection
            }
            .navigationTitle("Settings")
            .navBarInline()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveAndDismiss() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                schoolHost = AppSettings.schoolHost
                tokenText  = KeychainHelper.loadToken() ?? ""
            }
            .alert("Saved", isPresented: $savedToast) {
                Button("OK") {}
            } message: {
                Text("Your settings have been updated and the app will sync your planner.")
            }
            .alert("Disconnect from Canvas?", isPresented: $confirmSignOut) {
                Button("Cancel", role: .cancel) {}
                Button("Disconnect", role: .destructive) {
                    AppSettings.signOut()
                    store.clearCache()
                    store.periods = []
                    dismiss()
                }
            } message: {
                Text("This will remove your access token, school URL, and all cached planner data from this device.")
            }
        }
    }

    // MARK: - Sections

    private var canvasSection: some View {
        Section {
            // School URL
            VStack(alignment: .leading, spacing: 6) {
                Text("Canvas URL")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("yourschool.instructure.com", text: $schoolHost)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .noAutoCap()
                    .urlKeyboard()
                    .font(.system(size: 14, design: .monospaced))
            }
            .padding(.vertical, 4)

            // Token
            VStack(alignment: .leading, spacing: 6) {
                Text("Access Token")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showToken {
                            TextField("Paste token", text: $tokenText)
                                .autocorrectionDisabled()
                                .noAutoCap()
                        } else {
                            SecureField("Paste token", text: $tokenText)
                        }
                    }
                    .font(.system(size: 13, design: .monospaced))

                    Button { showToken.toggle() } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Canvas")
        } footer: {
            Text("Your token is stored securely in Keychain and only ever sent to your Canvas server.")
                .font(.caption2)
        }
    }

    private var howToSection: some View {
        Section("How to get an access token") {
            VStack(alignment: .leading, spacing: 6) {
                InfoStep(n: 1, text: "Open Canvas in Safari and sign in")
                InfoStep(n: 2, text: "Go to Account → Settings")
                InfoStep(n: 3, text: "Scroll to \"Approved Integrations\"")
                InfoStep(n: 4, text: "Tap \"+ New Access Token\" and copy it")
            }
            .padding(.vertical, 4)
        }
    }

    private var syncSection: some View {
        Section("Sync") {
            if let last = store.lastFetched {
                HStack {
                    Text("Last synced")
                    Spacer()
                    Text(last, style: .relative)
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            }

            Button {
                Task {
                    isRefreshing = true
                    await store.fetch()
                    isRefreshing = false
                }
            } label: {
                HStack {
                    Label("Refresh Now", systemImage: "arrow.clockwise")
                    Spacer()
                    if isRefreshing { ProgressView().controlSize(.small) }
                }
            }
            .disabled(isRefreshing)

            Button(role: .destructive) {
                store.clearCache()
            } label: {
                Label("Clear Cached Data", systemImage: "trash")
            }
        }
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .foregroundStyle(.secondary)
            }
            Link(destination: privacyPolicyURL) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
            }
        } header: {
            Text("About")
        } footer: {
            Text("FocusPlanner is not affiliated with Instructure, Inc., Canvas LMS, or any educational institution. It uses your personal Canvas access token to access your own data — no other servers are involved.")
                .font(.caption2)
        }
    }

    private var signOutSection: some View {
        Section {
            Button(role: .destructive) {
                confirmSignOut = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Disconnect from Canvas")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        let cleanedHost = AppSettings.normalize(schoolHost)
        let cleanedToken = tokenText.trimmingCharacters(in: .whitespaces)

        AppSettings.schoolHost = cleanedHost
        if !cleanedToken.isEmpty {
            KeychainHelper.saveToken(cleanedToken)
        }
        savedToast = true
        Task {
            await store.fetch()
            dismiss()
        }
    }
}

private struct InfoStep: View {
    let n: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.fpAccent, in: Circle())
            Text(text)
                .font(.callout)
        }
    }
}
