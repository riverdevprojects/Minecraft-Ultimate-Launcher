// ModpackExporter.swift

import Foundation
import AppKit

@MainActor
final class ModpackExporter: ObservableObject {
    @Published var isExporting: Bool = false
    @Published var error: Error?

    func export(modpack: Modpack, mods: [InstalledMod]) async -> URL? {
        isExporting = true
        error = nil

        do {
            let url = try await createExportZip(modpack: modpack, mods: mods)
            isExporting = false
            return url
        } catch {
            self.error = error
            isExporting = false
            return nil
        }
    }

    private func createExportZip(modpack: Modpack, mods: [InstalledMod]) async throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("export_\(modpack.id.uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let manifest = buildManifest(modpack: modpack, mods: mods)
        let manifestData = try JSONEncoder().encode(manifest)
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        try manifestData.write(to: manifestURL)

        let overridesDir = tempDir.appendingPathComponent("overrides")
        try FileManager.default.createDirectory(at: overridesDir, withIntermediateDirectories: true)

        let modsDir = URL(fileURLWithPath: modpack.instanceDirectory)
            .appendingPathComponent("mods")
        if FileManager.default.fileExists(atPath: modsDir.path) {
            let modFiles = try FileManager.default.contentsOfDirectory(
                at: modsDir, includingPropertiesForKeys: nil
            )
            let overridesMods = overridesDir.appendingPathComponent("mods")
            try FileManager.default.createDirectory(at: overridesMods, withIntermediateDirectories: true)
            for file in modFiles {
                let dest = overridesMods.appendingPathComponent(file.lastPathComponent)
                try? FileManager.default.copyItem(at: file, to: dest)
            }
        }

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(modpack.name.replacingOccurrences(of: " ", with: "_")).zip")

        try await zipDirectory(at: tempDir, to: zipURL)
        try? FileManager.default.removeItem(at: tempDir)

        return zipURL
    }

    private func buildManifest(modpack: Modpack, mods: [InstalledMod]) -> ExportManifest {
        let files = mods.map {
            ExportManifest.ModFile(projectID: $0.curseforgeModId, fileID: $0.curseforgeFileId, required: true)
        }
        return ExportManifest(
            minecraft: ExportManifest.MinecraftInfo(
                version: modpack.minecraftVersion,
                modLoaders: [ExportManifest.ModLoader(
                    id: "\(modpack.modLoaderType.rawValue)-\(modpack.modLoaderVersion)",
                    primary: true
                )]
            ),
            manifestType: "minecraftModpack",
            manifestVersion: 1,
            name: modpack.name,
            version: "1.0.0",
            overrides: "overrides",
            files: files
        )
    }

    private func zipDirectory(at sourceURL: URL, to destinationURL: URL) async throws {
        let coordinator = NSFileCoordinator()
        var coordError: NSError?
        var zipError: Error?

        coordinator.coordinate(readingItemAt: sourceURL, options: .forUploading, error: &coordError) { zipURL in
            do {
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                try FileManager.default.copyItem(at: zipURL, to: destinationURL)
            } catch {
                zipError = error
            }
        }

        if let error = coordError ?? zipError {
            throw error
        }
    }
}

// MARK: - ExportManifest

struct ExportManifest: Codable {
    struct MinecraftInfo: Codable {
        let version: String
        let modLoaders: [ModLoader]
    }
    struct ModLoader: Codable {
        let id: String
        let primary: Bool
    }
    struct ModFile: Codable {
        let projectID: Int
        let fileID: Int
        let required: Bool
    }

    let minecraft: MinecraftInfo
    let manifestType: String
    let manifestVersion: Int
    let name: String
    let version: String
    let overrides: String
    let files: [ModFile]
}
