import SwiftUI

struct POTAAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showingManualEntry = false
    @State private var pastedToken = ""
    @State private var pastedRefreshToken = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "tree.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("Sign in to POTA")
                    .font(.title2.bold())

                Text("VibeHam uses POTA\u{2019}s official sign-in page to download your full hunter logbook. Your password is never entered in this app.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()

                Button {
                    signIn()
                } label: {
                    if isWorking {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Sign In with POTA")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isWorking)

                Button("Paste Token Manually") {
                    showingManualEntry = true
                }
                .disabled(isWorking)

                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .disabled(isWorking)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isWorking)
                }
            }
        }
        .sheet(isPresented: $showingManualEntry) {
            POTAManualTokenView { idToken, refreshToken in
                POTAAuthManager.shared.saveManuallyPastedTokens(idToken: idToken, refreshToken: refreshToken)
                dismiss()
            }
        }
    }

    private func signIn() {
        isWorking = true
        errorMessage = nil
        Task {
            let result = await POTAAuthManager.shared.signIn()
            await MainActor.run {
                isWorking = false
                switch result {
                case .success:
                    dismiss()
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

struct POTAManualTokenView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var idToken = ""
    @State private var refreshToken = ""
    var onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $idToken)
                        .frame(minHeight: 80)
                        .font(.system(.body, design: .monospaced))
                    Text("Paste the id_token value from your POTA browser session.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("POTA ID Token")
                }

                Section {
                    TextEditor(text: $refreshToken)
                        .frame(minHeight: 60)
                        .font(.system(.body, design: .monospaced))
                    Text("Optional. Paste the refresh_token value to stay signed in longer.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("POTA Refresh Token (optional)")
                }

                Section {
                    Text("How to find your tokens:\n\n1. Log in to pota.app in Safari on a Mac.\n2. Open Safari Web Inspector (Develop menu).\n3. Run in the Console:\n\nObject.keys(localStorage).filter(k => k.includes(\"idToken\")).map(k => localStorage.getItem(k))\n\n4. Copy the long JWT string and paste it above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Paste POTA Token")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(idToken.trimmingCharacters(in: .whitespacesAndNewlines),
                               refreshToken.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .disabled(idToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    POTAAuthView()
}
