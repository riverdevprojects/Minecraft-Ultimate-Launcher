// SettingsView.swift

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("javaPathOverride") private var javaPathOverride: String = ""
    @AppStorage("defaultMinecraftVersion") private var defaultMinecraftVersion: String = "1.21.1"

    @State private var showResetConfirmation = false
    @State private var storagePath: String = ""

    private var applicationSupportURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("MinecraftUltimateLauncher")
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            storageTab
                .tabItem { Label("Storage", systemImage: "internaldrive") }

            apiTab
                .tabItem { Label("API", systemImage: "key") }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 300)
        .onAppear {
            storagePath = applicationSupportURL.path
        }
    }

    private var generalTab: some View {
        Form {
            Section("Java") {
                LabeledContent("Java Path Override") {
                    TextField("Leave blank to auto-detect", text: $javaPathOverride)
                        .frame(minWidth: 280)
                }
                .help("Specify a custom Java executable path. Leave blank to auto-detect.")

                if !javaPathOverride.isEmpty {
                    if FileManager.default.fileExists(atPath: javaPathOverride) {
                        Label("Java found at this path", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Label("Java not found at this path", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }

            Section("Defaults") {
                LabeledContent("Default Minecraft Version") {
                    Picker("", selection: $defaultMinecraftVersion) {
                        ForEach(["1.21.1", "1.20.1", "1.19.2", "1.18.2", "1.16.5"], id: \.self) { v in
                            Text(v).tag(v)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var storageTab: some View {
        Form {
            Section("Data Location") {
                LabeledContent("Storage Path") {
                    Text(storagePath)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: 300, alignment: .trailing)
                }

                HStack {
                    Spacer()
                    Button("Open in Finder") {
                        NSWorkspace.shared.open(applicationSupportURL)
                    }
                }
            }

            Section("Disk Usage") {
                LabeledContent("Instances Folder") {
                    let size = directorySize(applicationSupportURL)
                    Text(formatBytes(size))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private var apiTab: some View {
        Form {
            Section("CurseForge API") {
                LabeledContent("API Key Status") {
                    let hasKey = KeychainService.shared.load(
                        service: KeychainService.serviceName,
                        account: KeychainService.apiKeyAccount
                    ) != nil
                    Label(hasKey ? "Configured" : "Not set",
                          systemImage: hasKey ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(hasKey ? .green : .red)
                }

                HStack {
                    Spacer()
                    Button("Reset API Key", role: .destructive) {
                        showResetConfirmation = true
                    }
                    .confirmationDialog(
                        "Reset API Key",
                        isPresented: $showResetConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Reset", role: .destructive) {
                            KeychainService.shared.delete(
                                service: KeychainService.serviceName,
                                account: KeychainService.apiKeyAccount
                            )
                            appState.isOnboardingComplete = false
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("This will delete your API key and show the onboarding screen on next launch.")
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        let mb = Double(bytes) / 1_048_576
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}
