// DatabaseManager.swift

import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()
    private var dbQueue: DatabaseQueue!

    private init() {
        do {
            try setup()
        } catch {
            fatalError("DatabaseManager setup failed: \(error)")
        }
    }

    private func setup() throws {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("MinecraftUltimateLauncher")

        try FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)

        let dbPath = appSupport.appendingPathComponent("launcher.db").path
        dbQueue = try DatabaseQueue(path: dbPath)
        try runMigrations()
    }

    private func runMigrations() throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_initial") { db in
            try db.create(table: "modpacks", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("name", .text).notNull()
                t.column("minecraftVersion", .text).notNull()
                t.column("modLoaderType", .text).notNull()
                t.column("modLoaderVersion", .text).notNull()
                t.column("instanceDirectory", .text).notNull()
                t.column("iconPath", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("lastPlayed", .datetime)
            }

            try db.create(table: "installed_mods", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("modpackId", .text).notNull()
                    .references("modpacks", onDelete: .cascade)
                t.column("curseforgeModId", .integer).notNull()
                t.column("curseforgeFileId", .integer).notNull()
                t.column("name", .text).notNull()
                t.column("fileName", .text).notNull()
                t.column("version", .text).notNull()
                t.column("isEnabled", .boolean).notNull().defaults(to: true)
            }
        }

        try migrator.migrate(dbQueue)
    }

    // MARK: - Modpack CRUD

    func fetchAllModpacks() throws -> [Modpack] {
        try dbQueue.read { db in
            try Modpack.fetchAll(db)
        }
    }

    func save(modpack: Modpack) throws {
        try dbQueue.write { db in
            try modpack.save(db)
        }
    }

    func delete(modpack: Modpack) throws {
        try dbQueue.write { db in
            try modpack.delete(db)
        }
    }

    func updateLastPlayed(modpackId: UUID) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE modpacks SET lastPlayed = ? WHERE id = ?",
                arguments: [Date(), modpackId.uuidString]
            )
        }
    }

    // MARK: - InstalledMod CRUD

    func fetchMods(for modpackId: UUID) throws -> [InstalledMod] {
        try dbQueue.read { db in
            try InstalledMod
                .filter(Column("modpackId") == modpackId.uuidString)
                .fetchAll(db)
        }
    }

    func save(installedMod: InstalledMod) throws {
        try dbQueue.write { db in
            try installedMod.save(db)
        }
    }

    func delete(installedMod: InstalledMod) throws {
        try dbQueue.write { db in
            try installedMod.delete(db)
        }
    }

    func updateEnabled(modId: UUID, isEnabled: Bool) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE installed_mods SET isEnabled = ? WHERE id = ?",
                arguments: [isEnabled, modId.uuidString]
            )
        }
    }

    func isModInstalled(curseforgeModId: Int, in modpackId: UUID) throws -> Bool {
        try dbQueue.read { db in
            try InstalledMod
                .filter(Column("modpackId") == modpackId.uuidString)
                .filter(Column("curseforgeModId") == curseforgeModId)
                .fetchCount(db) > 0
        }
    }

    func modCount(for modpackId: UUID) throws -> Int {
        try dbQueue.read { db in
            try InstalledMod
                .filter(Column("modpackId") == modpackId.uuidString)
                .fetchCount(db)
        }
    }
}
