// MinecraftLauncher.swift

import Foundation
import AppKit

@MainActor
final class MinecraftLauncher: ObservableObject {
    @Published var isLaunching: Bool = false
    @Published var error: Error?

    func launch(modpack: Modpack) async {
        isLaunching = true
        error = nil

        do {
            try await performLaunch(modpack: modpack)
        } catch {
            self.error = error
        }

        isLaunching = false
    }

    private func performLaunch(modpack: Modpack) async throws {
        let launcherURL = findMinecraftLauncher()

        if let url = launcherURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.arguments = ["--gameDir", modpack.instanceDirectory]
            try await NSWorkspace.shared.open([], withApplicationAt: url, configuration: configuration)
        } else {
            throw LaunchError.launcherNotFound
        }

        try DatabaseManager.shared.updateLastPlayed(modpackId: modpack.id)
    }

    private func findMinecraftLauncher() -> URL? {
        let candidates = [
            "/Applications/Minecraft.app",
            "\(NSHomeDirectory())/Applications/Minecraft.app"
        ]
        for path in candidates {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                return url
            }
        }
        return nil
    }

    func isLauncherInstalled() -> Bool {
        findMinecraftLauncher() != nil
    }
}

// MARK: - LaunchError

enum LaunchError: LocalizedError {
    case launcherNotFound
    case launchFailed(Error)

    var errorDescription: String? {
        switch self {
        case .launcherNotFound:
            return "Minecraft launcher not found. Please install Minecraft from minecraft.net."
        case .launchFailed(let err):
            return "Failed to launch Minecraft: \(err.localizedDescription)"
        }
    }
}
