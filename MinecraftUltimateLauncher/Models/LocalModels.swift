// LocalModels.swift

import Foundation
import GRDB

// MARK: - ModLoaderType

enum ModLoaderType: String, Codable, CaseIterable {
    case forge = "forge"
    case neoforge = "neoforge"
    case fabric = "fabric"

    var displayName: String {
        switch self {
        case .forge: return "Forge"
        case .neoforge: return "NeoForge"
        case .fabric: return "Fabric"
        }
    }
}

// MARK: - Modpack

struct Modpack: Codable, Identifiable, Hashable, FetchableRecord, PersistableRecord {
    var id: UUID
    var name: String
    var minecraftVersion: String
    var modLoaderType: ModLoaderType
    var modLoaderVersion: String
    var instanceDirectory: String
    var iconPath: String?
    var createdAt: Date
    var lastPlayed: Date?

    static let databaseTableName = "modpacks"

    static func == (lhs: Modpack, rhs: Modpack) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var instanceURL: URL {
        URL(fileURLWithPath: instanceDirectory)
    }

    var modsDirectoryURL: URL {
        instanceURL.appendingPathComponent("mods")
    }

    static func makeNew(
        name: String,
        minecraftVersion: String,
        modLoaderType: ModLoaderType,
        modLoaderVersion: String
    ) -> Modpack {
        let id = UUID()
        let baseDir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("MinecraftUltimateLauncher")
            .appendingPathComponent("instances")
            .appendingPathComponent(id.uuidString)
        return Modpack(
            id: id,
            name: name,
            minecraftVersion: minecraftVersion,
            modLoaderType: modLoaderType,
            modLoaderVersion: modLoaderVersion,
            instanceDirectory: baseDir.path,
            iconPath: nil,
            createdAt: Date(),
            lastPlayed: nil
        )
    }
}

// MARK: - InstalledMod

struct InstalledMod: Codable, Identifiable, Hashable, FetchableRecord, PersistableRecord {
    var id: UUID
    var modpackId: UUID
    var curseforgeModId: Int
    var curseforgeFileId: Int
    var name: String
    var fileName: String
    var version: String
    var isEnabled: Bool

    static let databaseTableName = "installed_mods"

    static func == (lhs: InstalledMod, rhs: InstalledMod) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
