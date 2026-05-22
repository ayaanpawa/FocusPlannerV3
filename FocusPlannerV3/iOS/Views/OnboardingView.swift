import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss

    @State private var step:      Int    = 0
    @State private var schoolURL: String = ""
    @State private var token:     String = ""
    @State private var showToken: Bool   = false
    @State private var isVerifying = false
    @State private var errorText:  String?

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(colors: [Color.fpAccent.opacity(0.10), Color.fpMustard.opacity(0.06)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        header
                        Group {
                            switch step {
                            case 0: welcomePage
                            case 1: schoolPage
                            case 2: tokenPage
                            default: EmptyView()
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))

                        if let err = errorText {
                            Text(err)
                                .font(.callout)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }

                        primaryButton
                        if step > 0 {
                            Button("Back") {
                                withAnimation { step -= 1; errorText = nil }
                            }
                            .font(.callout)
                        }

                        disclaimer
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
            }
            .navBarHidden()
        }
        .stackNavStyle()
        .interactiveDismissDisabled()
        #if os(macOS)
        .frame(width: 520, height: 640)
        #endif
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "graduationcap.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.fpAccent.gradient)

            Text("FocusPlanner")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text("Step \(step + 1) of 3")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 16)
    }

    // MARK: - Pages

    private var welcomePage: some View {
        VStack(spacing: 18) {
            Text("Your Canvas planner,\nin one clean place.")
                .font(.system(size: 22, weight: .semibold))
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 14) {
                feature(icon: "calendar",       title: "See homework & tests on a clean calendar")
                feature(icon: "checklist",      title: "Mark assignments done — syncs to Canvas")
                feature(icon: "lock.fill",      title: "Your data stays on your device")
            }
            .padding(20)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        }
    }

    private var schoolPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's your school's Canvas address?")
                .font(.system(size: 20, weight: .semibold))

            Text("Look at your browser when you're logged into Canvas. It's the part before \"/courses\".")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Canvas URL")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("yourschool.instructure.com", text: $schoolURL)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .noAutoCap()
                    .urlKeyboard()
                    .font(.system(size: 15, design: .monospaced))
                    .padding(12)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 6)
        }
    }

    private var tokenPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Now your access token")
                .font(.system(size: 20, weight: .semibold))

            VStack(alignment: .leading, spacing: 8) {
                step(1, "In Safari, open your Canvas account")
                step(2, "Go to Account → Settings")
                step(3, "Scroll to \"Approved Integrations\"")
                step(4, "Tap \"+ New Access Token\" and copy it")
            }
            .padding(14)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text("Paste it here")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Group {
                        if showToken {
                            TextField("Token", text: $token)
                                .autocorrectionDisabled()
                                .noAutoCap()
                        } else {
                            SecureField("Token", text: $token)
                        }
                    }
                    .font(.system(size: 13, design: .monospaced))

                    Button { showToken.toggle() } label: {
                        Image(systemName: showToken ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))

                Text("Stored securely in Keychain. Never sent anywhere except Canvas.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 6)
        }
    }

    // MARK: - Action

    private var primaryButton: some View {
        Button {
            handleNext()
        } label: {
            HStack {
                Text(step == 2 ? (isVerifying ? "Connecting…" : "Get Started") : "Continue")
                    .font(.system(size: 16, weight: .semibold))
                if isVerifying { ProgressView().tint(.white) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.fpAccent, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(.white)
        }
        .disabled(isVerifying || !canAdvance)
        .opacity(canAdvance ? 1.0 : 0.4)
        .padding(.top, 6)
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return true
        case 1: return !AppSettings.normalize(schoolURL).isEmpty
        case 2: return !token.trimmingCharacters(in: .whitespaces).isEmpty
        default: return false
        }
    }

    private func handleNext() {
        errorText = nil
        switch step {
        case 0:
            withAnimation { step = 1 }
        case 1:
            AppSettings.schoolHost = schoolURL
            withAnimation { step = 2 }
        case 2:
            Task { await finish() }
        default: break
        }
    }

    private func finish() async {
        isVerifying = true
        defer { isVerifying = false }

        let cleaned = token.trimmingCharacters(in: .whitespaces)
        KeychainHelper.saveToken(cleaned)

        // Smoke-test the token by hitting /courses; if it fails, surface the error
        do {
            _ = try await CanvasService.shared.fetchCourses(token: cleaned)
            AppSettings.hasOnboarded = true
            await store.fetch()
            dismiss()
        } catch {
            errorText = error.localizedDescription
            KeychainHelper.deleteToken()
        }
    }

    // MARK: - UI pieces

    private func feature(icon: String, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.fpAccent)
                .frame(width: 26, height: 26)
                .background(Color.fpAccent.opacity(0.12), in: Circle())
            Text(title)
                .font(.system(size: 14))
            Spacer()
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Color.fpAccent, in: Circle())
            Text(text)
                .font(.system(size: 13))
            Spacer()
        }
    }

    private var disclaimer: some View {
        Text("FocusPlanner is not affiliated with Instructure, Inc. or your school. It accesses your own Canvas data using a personal access token you provide.")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
    }
}
