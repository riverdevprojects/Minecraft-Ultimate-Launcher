// DependencyResolver.swift

import Foundation

// MARK: - DependencyResolution Result

struct DependencyResolutionResult {
    let required: [DependencyItem]
    let optional: [DependencyItem]
}

struct DependencyItem: Identifiable {
    let id = UUID()
    let mod: CFMod
    let file: CFModFile
}

// MARK: - DependencyResolver

@MainActor
final class DependencyResolver {
    private let api = CurseForgeAPIService.shared
    private var visited: Set<Int> = []
    private var required: [DependencyItem] = []
    private var optional: [DependencyItem] = []

    func resolve(
        dependencies: [CFModDependency],
        gameVersion: String
    ) async throws -> DependencyResolutionResult {
        visited.removeAll()
        required.removeAll()
        optional.removeAll()

        try await resolveDependencies(dependencies, gameVersion: gameVersion)

        return DependencyResolutionResult(required: required, optional: optional)
    }

    private func resolveDependencies(
        _ dependencies: [CFModDependency],
        gameVersion: String
    ) async throws {
        for dep in dependencies {
            guard !visited.contains(dep.modId) else { continue }
            visited.insert(dep.modId)

            let mod = try await api.getModDetails(modId: dep.modId)
            let files = try await api.getModFiles(modId: dep.modId, gameVersion: gameVersion)

            guard let latestFile = files.first else { continue }

            let item = DependencyItem(mod: mod, file: latestFile)

            if dep.isRequired {
                required.append(item)
                try await resolveDependencies(latestFile.dependencies, gameVersion: gameVersion)
            } else if dep.isOptional {
                optional.append(item)
            }
        }
    }
}
