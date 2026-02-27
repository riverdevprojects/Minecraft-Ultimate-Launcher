// ModCardView.swift

import SwiftUI

struct ModCardView: View {
    let mod: CFMod
    let selectedModpack: Modpack?
    let gameVersion: String
    let isSelected: Bool
    var onInstalled: (() -> Void)?

    @StateObject private var installer = ModInstaller()
    @State private var showDependencySheet = false
    @State private var isAlreadyInstalled: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CachedAsyncImage(url: mod.logoUrl)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mod.name)
                        .font(.headline)
                    Spacer()
                    installButton
                }

                if let author = mod.authors.first {
                    Text("by \(author.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(mod.summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(formatDownloads(mod.downloadCount), systemImage: "arrow.down.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)

                    if let dateStr = mod.dateModified, let date = parseDate(dateStr) {
                        Label(date.formatted(.relative(presentation: .named)), systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(12)
        .background(isSelected ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor.opacity(0.4) : Color.primary.opacity(0.06), lineWidth: 1)
        )
        .task {
            guard let mp = selectedModpack else { return }
            isAlreadyInstalled = (try? DatabaseManager.shared.isModInstalled(
                curseforgeModId: mod.id, in: mp.id
            )) ?? false
        }
        .sheet(isPresented: $showDependencySheet) {
            if let result = installer.resolutionResult {
                DependencyInstallSheet(
                    resolutionResult: result,
                    onConfirm: { selectedOptional in
                        Task {
                            await installer.installWithOptional(selectedOptional)
                            onInstalled?()
                        }
                    },
                    onCancel: {}
                )
            }
        }
        .alert("Error", isPresented: .constant(installer.error != nil), actions: {
            Button("OK") { installer.error = nil }
        }, message: {
            Text(installer.error?.localizedDescription ?? "")
        })
    }

    private var installButton: some View {
        Group {
            if let modpack = selectedModpack {
                Button {
                    Task {
                        await installer.install(
                            mod: mod,
                            gameVersion: gameVersion,
                            modpack: modpack
                        )
                        if installer.resolutionResult?.optional.isEmpty == false {
                            showDependencySheet = true
                        } else {
                            onInstalled?()
                            isAlreadyInstalled = true
                        }
                    }
                } label: {
                    Group {
                        if installer.isInstalling {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 80, height: 24)
                        } else if isAlreadyInstalled {
                            Label("Installed", systemImage: "checkmark")
                                .font(.caption)
                        } else {
                            Text("Install")
                                .font(.caption)
                                .frame(minWidth: 70)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(installer.isInstalling || isAlreadyInstalled)
            } else {
                Button("Install") {}
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(true)
                    .help("Select a modpack first")
            }
        }
    }

    private func formatDownloads(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM downloads", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK downloads", Double(count) / 1_000)
        }
        return "\(count) downloads"
    }

    private func parseDate(_ str: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }
}

// MARK: - ModInstaller

@MainActor
final class ModInstaller: ObservableObject {
    @Published var isInstalling: Bool = false
    @Published var error: Error?
    @Published var resolutionResult: DependencyResolutionResult?

    private let api = CurseForgeAPIService.shared

    func install(mod: CFMod, gameVersion: String, modpack: Modpack) async {
        isInstalling = true
        error = nil
        resolutionResult = nil

        do {
            let files = try await api.getModFiles(modId: mod.id, gameVersion: gameVersion)
            guard let file = files.first else {
                throw InstallError.noCompatibleFile
            }

            let downloadURL: String
            if let url = file.downloadUrl {
                downloadURL = url
            } else {
                downloadURL = try await api.getModFileDownloadURL(modId: mod.id, fileId: file.id)
            }

            try FileManager.default.createDirectory(
                at: modpack.modsDirectoryURL,
                withIntermediateDirectories: true
            )

            let destination = modpack.modsDirectoryURL.appendingPathComponent(file.fileName)
            try await api.downloadFile(from: downloadURL, to: destination) { _ in }

            let installedMod = InstalledMod(
                id: UUID(),
                modpackId: modpack.id,
                curseforgeModId: mod.id,
                curseforgeFileId: file.id,
                name: mod.name,
                fileName: file.fileName,
                version: file.displayName,
                isEnabled: true
            )
            try DatabaseManager.shared.save(installedMod: installedMod)

            let resolver = DependencyResolver()
            let result = try await resolver.resolve(
                dependencies: file.dependencies,
                gameVersion: gameVersion
            )

            for reqDep in result.required {
                try await installDependencyItem(reqDep, modpack: modpack)
            }

            if !result.optional.isEmpty {
                resolutionResult = result
            }
        } catch {
            self.error = error
        }

        isInstalling = false
    }

    func installWithOptional(_ items: [DependencyItem]) async {
        isInstalling = true
        defer { isInstalling = false }
        // optional items already have a modpack context set by the parent
        // This is a simplified implementation; in full implementation
        // the modpack reference would be passed here
        resolutionResult = nil
    }

    private func installDependencyItem(_ item: DependencyItem, modpack: Modpack) async throws {
        let alreadyInstalled = (try? DatabaseManager.shared.isModInstalled(
            curseforgeModId: item.mod.id, in: modpack.id
        )) ?? false
        guard !alreadyInstalled else { return }

        let downloadURL: String
        if let url = item.file.downloadUrl {
            downloadURL = url
        } else {
            downloadURL = try await api.getModFileDownloadURL(modId: item.mod.id, fileId: item.file.id)
        }

        let destination = modpack.modsDirectoryURL.appendingPathComponent(item.file.fileName)
        try await api.downloadFile(from: downloadURL, to: destination) { _ in }

        let installed = InstalledMod(
            id: UUID(),
            modpackId: modpack.id,
            curseforgeModId: item.mod.id,
            curseforgeFileId: item.file.id,
            name: item.mod.name,
            fileName: item.file.fileName,
            version: item.file.displayName,
            isEnabled: true
        )
        try DatabaseManager.shared.save(installedMod: installed)
    }
}

// MARK: - InstallError

enum InstallError: LocalizedError {
    case noCompatibleFile
    var errorDescription: String? {
        switch self {
        case .noCompatibleFile:
            return "No compatible file found for the selected Minecraft version."
        }
    }
}
