// OnboardingView.swift

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppState
    @State private var apiKey: String = ""
    @State private var errorMessage: String?
    @State private var isSaving: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 72))
                .foregroundStyle(.green)

            VStack(spacing: 12) {
                Text("Welcome to Minecraft Ultimate Launcher")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("To browse and install mods from CurseForge, you need a CurseForge API key.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)

                Link("Get your API key at curseforge.com/account/api-keys",
                     destination: URL(string: "https://console.curseforge.com/#/api-keys")!)
                    .font(.callout)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("CurseForge API Key")
                    .font(.headline)

                SecureField("Paste your API key here", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 480)

                if let msg = errorMessage {
                    Label(msg, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }

            Button(action: saveAndContinue) {
                if isSaving {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 120, height: 24)
                } else {
                    Text("Save & Continue")
                        .frame(width: 120, height: 24)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

            Spacer()
        }
        .padding(48)
        .frame(minWidth: 600, minHeight: 500)
    }

    private func saveAndContinue() {
        let trimmed = apiKey.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = "API key cannot be empty."
            return
        }
        isSaving = true
        errorMessage = nil

        KeychainService.shared.save(
            key: trimmed,
            service: KeychainService.serviceName,
            account: KeychainService.apiKeyAccount
        )
        CurseForgeAPIService.shared.refreshAPIKey()
        appState.completeOnboarding()
    }
}
