// ModLoaderProgressSheet.swift

import SwiftUI

struct ModLoaderProgressSheet: View {
    @ObservedObject var installer: ModLoaderInstaller
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 12) {
                if installer.isInstalling {
                    ProgressView()
                } else {
                    Image(systemName: installer.error == nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(installer.error == nil ? .green : .red)
                        .font(.title2)
                }
                Text(installer.isInstalling ? "Installing Mod Loader..." : (installer.error == nil ? "Installation Complete" : "Installation Failed"))
                    .font(.headline)
            }

            ProgressView(value: installer.progress, total: 1.0)
                .progressViewStyle(.linear)

            ScrollView {
                Text(installer.logOutput)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )

            if !installer.isInstalling {
                Button("Close") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 500, minHeight: 340)
    }
}
