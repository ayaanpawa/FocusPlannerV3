import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: PlannerStore
    @Environment(\.dismiss) private var dismiss

    @State private var tokenText   = ""
    @State private var showToken   = false
    @State private var saved       = false
    @State private var isRefreshing = false

    var body: some View {
        NavigationView {
            Form {
                // MARK: Canvas Token
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Canvas API Token")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack {
                            Group {
                                if showToken {
                                    TextField("Paste token here", text: $tokenText)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                } else {
                                    SecureField("Paste token here", text: $tokenText)
                                }
                            }
                            .font(.system(size: 13, design: .monospaced))

                            Button {
                                showToken.toggle()
                            } label: {
                                Image(systemName: showToken ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }

                        Text("Your token is stored securely in Keychain and never leaves your device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Canvas LMS")
                } footer: {
                    Text("School: halfhollowhills.instructure.com")
                        .font(.caption2)
                }

                // MARK: How to get token
                Section("How to get your token") {
                    VStack(alignment: .leading, spacing: 6) {
                        InfoStep(n: 1, text: "Open Canvas in Safari")
                        InfoStep(n: 2, text: "Go to Account → Settings")
                        InfoStep(n: 3, text: "Scroll to \"Approved Integrations\"")
                        InfoStep(n: 4, text: "Tap \"+ New Access Token\" and copy it")
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Sync status
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

                // MARK: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("School")
                        Spacer()
                        Text("Half Hollow Hills")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = tokenText.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            KeychainHelper.saveToken(trimmed)
                            saved = true
                            Task {
                                await store.fetch()
                                dismiss()
                            }
                        } else {
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                tokenText = KeychainHelper.loadToken() ?? ""
            }
            .alert("Token Saved", isPresented: $saved) {
                Button("OK") {}
            } message: {
                Text("Your Canvas token has been saved and the app will now sync your planner.")
            }
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
                .background(Color.blue, in: Circle())
            Text(text)
                .font(.callout)
        }
    }
}
