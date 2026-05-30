import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss

    @State private var schoolHost      = ""
    @State private var tokenText       = ""
    @State private var showToken       = false
    @State private var isRefreshing    = false
    @State private var savedToast      = false
    @State private var confirmSignOut  = false

    /// Replace this URL with wherever you host your real privacy policy.
    private let privacyPolicyURL = URL(string: "https://example.com/focusplanner-privacy")!

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider().background(Color.fpDivider)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    canvasSection
                    howToSection
                    syncSection
                    aboutSection
                    signOutSection
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fpBg)
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
        #if os(macOS)
        .frame(width: 520, height: 640)
        #endif
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Settings")
                .font(.fpHeadline(28))
                .foregroundStyle(Color.fpInk)
            Spacer()
            HStack(spacing: 14) {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.fpMono(12))
                    .foregroundStyle(Color.fpInkMuted)
                Button("Save") { saveAndDismiss() }
                    .buttonStyle(.plain)
                    .font(.fpBody(13, weight: .semibold))
                    .foregroundStyle(Color.fpBg)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.fpInk, in: Capsule())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Sections

    private var canvasSection: some View {
        sectionBlock(title: "Canvas") {
            fieldLabel("Canvas URL") {
                TextField("yourschool.instructure.com", text: $schoolHost)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .noAutoCap()
                    .urlKeyboard()
                    .font(.fpMono(13))
                    .foregroundStyle(Color.fpInk)
                    .padding(12)
                    .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.fpDivider, lineWidth: 1)
                    )
            }

            fieldLabel("Access Token") {
                HStack(spacing: 8) {
                    Group {
                        if showToken {
                            TextField("Paste token", text: $tokenText)
                                .autocorrectionDisabled()
                                .noAutoCap()
                        } else {
                            SecureField("Paste token", text: $tokenText)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.fpMono(12))
                    .foregroundStyle(Color.fpInk)

                    Button { showToken.toggle() } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.fpInkMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.fpDivider, lineWidth: 1)
                )
            }

            Text("Your token is stored securely in Keychain and only ever sent to your Canvas server.")
                .font(.fpMono(10))
                .foregroundStyle(Color.fpInkSubtle)
                .lineSpacing(2)
        }
    }

    private var howToSection: some View {
        sectionBlock(title: "How to get an access token") {
            VStack(alignment: .leading, spacing: 9) {
                InfoStep(n: 1, text: "Open Canvas in Safari and sign in")
                InfoStep(n: 2, text: "Go to Account → Settings")
                InfoStep(n: 3, text: "Scroll to \"Approved Integrations\"")
                InfoStep(n: 4, text: "Tap \"+ New Access Token\" and copy it")
            }
        }
    }

    private var syncSection: some View {
        sectionBlock(title: "Sync") {
            VStack(alignment: .leading, spacing: 10) {
                if let last = store.lastFetched {
                    HStack {
                        Text("Last synced")
                            .font(.fpMono(12))
                            .foregroundStyle(Color.fpInkMuted)
                        Spacer()
                        Text(last, style: .relative)
                            .font(.fpMono(12))
                            .foregroundStyle(Color.fpInk)
                    }
                }

                Button {
                    Task {
                        isRefreshing = true
                        await store.fetch()
                        isRefreshing = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Refresh Now")
                            .font(.fpBody(13, weight: .semibold))
                        Spacer()
                        if isRefreshing { ProgressView().controlSize(.small) }
                    }
                    .foregroundStyle(Color.fpInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.fpDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)

                Button { store.clearCache() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Clear Cached Data")
                            .font(.fpBody(13, weight: .semibold))
                        Spacer()
                    }
                    .foregroundStyle(Color.fpAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.fpAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var aboutSection: some View {
        sectionBlock(title: "About") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Version")
                        .font(.fpMono(12))
                        .foregroundStyle(Color.fpInkMuted)
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .font(.fpMono(12))
                        .foregroundStyle(Color.fpInk)
                }
                Link(destination: privacyPolicyURL) {
                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Privacy Policy")
                            .font(.fpBody(13, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(Color.fpInk)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.fpBgRaised, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color.fpDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                Text("FocusPlanner is not affiliated with Instructure, Inc., Canvas LMS, or any educational institution. It uses your personal Canvas access token to access your own data — no other servers are involved.")
                    .font(.fpMono(10))
                    .foregroundStyle(Color.fpInkSubtle)
                    .lineSpacing(2)
            }
        }
    }

    private var signOutSection: some View {
        Button { confirmSignOut = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
                Text("Disconnect from Canvas")
                    .font(.fpBody(13, weight: .semibold))
                Spacer()
            }
            .foregroundStyle(Color.fpAccent)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.fpAccent.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.fpAccent.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Layout helpers

    @ViewBuilder
    private func sectionBlock<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.fpMono(10, weight: .bold))
                .foregroundStyle(Color.fpInkSubtle)
                .kerning(0.6)
            content()
        }
    }

    @ViewBuilder
    private func fieldLabel<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.fpMono(11, weight: .medium))
                .foregroundStyle(Color.fpInkMuted)
            content()
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        let cleanedHost  = AppSettings.normalize(schoolHost)
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
                .font(.fpMono(10, weight: .bold))
                .foregroundStyle(Color.fpBg)
                .frame(width: 18, height: 18)
                .background(Color.fpAccent, in: Circle())
            Text(text)
                .font(.fpBody(13, weight: .regular))
                .foregroundStyle(Color.fpInk)
        }
    }
}
