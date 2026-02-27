// ModLoaderInstaller.swift

import Foundation

// MARK: - ModLoaderInstaller

@MainActor
final class ModLoaderInstaller: ObservableObject {
    @Published var isInstalling: Bool = false
    @Published var progress: Double = 0
    @Published var logOutput: String = ""
    @Published var error: Error?

    private let session = URLSession.shared

    func install(
        modLoaderType: ModLoaderType,
        mcVersion: String,
        loaderVersion: String,
        instanceDirectory: URL
    ) async {
        isInstalling = true
        progress = 0
        logOutput = ""
        error = nil

        do {
            switch modLoaderType {
            case .forge:
                try await installForge(mcVersion: mcVersion, forgeVersion: loaderVersion, instanceDirectory: instanceDirectory)
            case .neoforge:
                try await installNeoForge(neoForgeVersion: loaderVersion, instanceDirectory: instanceDirectory)
            case .fabric:
                try await installFabric(mcVersion: mcVersion, loaderVersion: loaderVersion, instanceDirectory: instanceDirectory)
            }
            appendLog("Installation complete.")
        } catch {
            self.error = error
            appendLog("Error: \(error.localizedDescription)")
        }

        isInstalling = false
    }

    // MARK: - Java Detection

    func detectJava() -> String? {
        let commonPaths = [
            "/usr/bin/java",
            "/usr/local/bin/java",
            "/opt/homebrew/bin/java",
            "/Library/Java/JavaVirtualMachines/temurin-21.jdk/Contents/Home/bin/java",
            "/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home/bin/java"
        ]
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        let result = shell("which java")
        if let path = result?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty {
            return path
        }
        return nil
    }

    // MARK: - Forge

    private func installForge(mcVersion: String, forgeVersion: String, instanceDirectory: URL) async throws {
        let installerURL = "https://maven.minecraftforge.net/net/minecraftforge/forge/\(mcVersion)-\(forgeVersion)/forge-\(mcVersion)-\(forgeVersion)-installer.jar"
        appendLog("Downloading Forge installer...")
        let jarPath = try await downloadInstaller(from: installerURL, named: "forge-installer.jar")
        appendLog("Running Forge installer...")
        try await runInstaller(jarPath: jarPath, gameDir: instanceDirectory.path)
    }

    // MARK: - NeoForge

    private func installNeoForge(neoForgeVersion: String, instanceDirectory: URL) async throws {
        let installerURL = "https://maven.neoforged.net/releases/net/neoforged/neoforge/\(neoForgeVersion)/neoforge-\(neoForgeVersion)-installer.jar"
        appendLog("Downloading NeoForge installer...")
        let jarPath = try await downloadInstaller(from: installerURL, named: "neoforge-installer.jar")
        appendLog("Running NeoForge installer...")
        try await runInstaller(jarPath: jarPath, gameDir: instanceDirectory.path)
    }

    // MARK: - Fabric

    private func installFabric(mcVersion: String, loaderVersion: String, instanceDirectory: URL) async throws {
        let installerURL = "https://maven.fabricmc.net/net/fabricmc/fabric-installer/1.0.1/fabric-installer-1.0.1.jar"
        appendLog("Downloading Fabric installer...")
        let jarPath = try await downloadInstaller(from: installerURL, named: "fabric-installer.jar")
        appendLog("Running Fabric installer...")
        guard let java = detectJava() else {
            throw ModLoaderError.javaNotFound
        }
        let args = [java, "-jar", jarPath, "client",
                    "-mcversion", mcVersion,
                    "-loader", loaderVersion,
                    "-dir", instanceDirectory.path]
        try await runProcess(args: args)
    }

    // MARK: - Helpers

    private func downloadInstaller(from urlString: String, named name: String) async throws -> String {
        guard let url = URL(string: urlString) else {
            throw ModLoaderError.invalidURL
        }
        let tempDir = FileManager.default.temporaryDirectory
        let destination = tempDir.appendingPathComponent(name)
        appendLog("Downloading from: \(urlString)")

        let (asyncBytes, response) = try await session.bytes(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ModLoaderError.downloadFailed(http.statusCode)
        }
        let totalLength = response.expectedContentLength
        var receivedLength: Int64 = 0
        var data = Data()

        for try await byte in asyncBytes {
            data.append(byte)
            receivedLength += 1
            if totalLength > 0 {
                let p = Double(receivedLength) / Double(totalLength) * 0.5
                await MainActor.run { self.progress = p }
            }
        }
        try data.write(to: destination)
        return destination.path
    }

    private func runInstaller(jarPath: String, gameDir: String) async throws {
        guard let java = detectJava() else {
            throw ModLoaderError.javaNotFound
        }
        let args = [java, "-jar", jarPath, "--installClient", "--installDir=\(gameDir)"]
        try await runProcess(args: args)
    }

    private func runProcess(args: [String]) async throws {
        guard let java = args.first else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: java)
        process.arguments = Array(args.dropFirst())

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let handle = pipe.fileHandleForReading
        await withCheckedContinuation { continuation in
            handle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.resume()
                } else if let line = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        self.appendLog(line)
                        self.progress = min(self.progress + 0.05, 0.95)
                    }
                }
            }
        }
        process.waitUntilExit()
        await MainActor.run { self.progress = 1.0 }

        if process.terminationStatus != 0 {
            throw ModLoaderError.installerFailed(Int(process.terminationStatus))
        }
    }

    private func appendLog(_ line: String) {
        logOutput += line + "\n"
    }

    private func shell(_ command: String) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        let pipe = Pipe()
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
    }
}

// MARK: - ModLoaderError

enum ModLoaderError: LocalizedError {
    case javaNotFound
    case invalidURL
    case downloadFailed(Int)
    case installerFailed(Int)

    var errorDescription: String? {
        switch self {
        case .javaNotFound:
            return "Java not found. Please install Java and set the path in Settings."
        case .invalidURL:
            return "Invalid installer URL."
        case .downloadFailed(let code):
            return "Download failed with HTTP \(code)."
        case .installerFailed(let code):
            return "Installer exited with code \(code)."
        }
    }
}
