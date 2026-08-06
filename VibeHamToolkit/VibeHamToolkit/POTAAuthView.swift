import SwiftUI

struct POTAAuthView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "tree.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green)

                Text("Sign in to POTA")
                    .font(.title2.bold())

                Text("VibeHam uses POTA’s official sign-in page to download your full hunter logbook. Your password is never entered in this app.")
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

#Preview {
    POTAAuthView()
}
