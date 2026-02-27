// CurseForgeAPIService.swift

import Foundation

@MainActor
final class CurseForgeAPIService: ObservableObject {
    static let shared = CurseForgeAPIService()

    private let baseURL = "https://api.curseforge.com/v1"
    static let minecraftGameId = 432
    private var apiKey: String?
    private let session: URLSession

    private init() {
        apiKey = KeychainService.shared.load(
            service: KeychainService.serviceName,
            account: KeychainService.apiKeyAccount
        )
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    func refreshAPIKey() {
        apiKey = KeychainService.shared.load(
            service: KeychainService.serviceName,
            account: KeychainService.apiKeyAccount
        )
    }

    // MARK: - Request Building

    private func makeRequest(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        guard let key = apiKey, !key.isEmpty else {
            throw CurseForgeError.noAPIKey
        }
        var components = URLComponents(string: baseURL + path)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }
        guard let url = components?.url else {
            throw CurseForgeError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw CurseForgeError.networkError(error)
        }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw CurseForgeError.httpError(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CurseForgeError.decodingError(error)
        }
    }

    // MARK: - API Methods

    func searchMods(
        query: String,
        gameVersion: String? = nil,
        categoryId: Int? = nil,
        pageSize: Int = 20,
        index: Int = 0
    ) async throws -> [CFMod] {
        var items: [URLQueryItem] = [
            URLQueryItem(name: "gameId", value: "\(CurseForgeAPIService.minecraftGameId)"),
            URLQueryItem(name: "searchFilter", value: query),
            URLQueryItem(name: "pageSize", value: "\(pageSize)"),
            URLQueryItem(name: "index", value: "\(index)")
        ]
        if let version = gameVersion {
            items.append(URLQueryItem(name: "gameVersion", value: version))
        }
        if let cat = categoryId {
            items.append(URLQueryItem(name: "categoryId", value: "\(cat)"))
        }
        let request = try makeRequest(path: "/mods/search", queryItems: items)
        let response: CFPaginatedResponse<CFMod> = try await perform(request)
        return response.data
    }

    func getModDetails(modId: Int) async throws -> CFMod {
        let request = try makeRequest(path: "/mods/\(modId)")
        let response: CFResponse<CFMod> = try await perform(request)
        return response.data
    }

    func getModFiles(modId: Int, gameVersion: String? = nil) async throws -> [CFModFile] {
        var items: [URLQueryItem] = []
        if let version = gameVersion {
            items.append(URLQueryItem(name: "gameVersion", value: version))
        }
        let request = try makeRequest(path: "/mods/\(modId)/files", queryItems: items)
        let response: CFPaginatedResponse<CFModFile> = try await perform(request)
        return response.data
    }

    func getModFileDownloadURL(modId: Int, fileId: Int) async throws -> String {
        let request = try makeRequest(path: "/mods/\(modId)/files/\(fileId)/download-url")
        let response: CFResponse<String?> = try await perform(request)
        guard let url = response.data else {
            throw CurseForgeError.noDownloadURL
        }
        return url
    }

    func getCategories() async throws -> [CFCategory] {
        let items = [URLQueryItem(name: "gameId", value: "\(CurseForgeAPIService.minecraftGameId)")]
        let request = try makeRequest(path: "/categories", queryItems: items)
        let response: CFResponse<[CFCategory]> = try await perform(request)
        return response.data
    }

    // MARK: - File Download

    func downloadFile(
        from urlString: String,
        to destination: URL,
        progress: @escaping (Double) -> Void
    ) async throws {
        guard let url = URL(string: urlString) else {
            throw CurseForgeError.invalidURL
        }
        let (asyncBytes, response) = try await session.bytes(from: url)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw CurseForgeError.httpError(http.statusCode)
        }
        let totalLength = response.expectedContentLength
        var receivedLength: Int64 = 0
        var data = Data()

        for try await byte in asyncBytes {
            data.append(byte)
            receivedLength += 1
            if totalLength > 0 {
                progress(Double(receivedLength) / Double(totalLength))
            }
        }
        try data.write(to: destination)
    }

    // MARK: - Loader Version APIs

    func fetchNeoForgeVersions(for mcVersion: String) async throws -> [String] {
        let urlString = "https://maven.neoforged.net/api/maven/versions/releases/net/neoforged/neoforge"
        guard let url = URL(string: urlString) else { throw CurseForgeError.invalidURL }
        let (data, _) = try await session.data(from: url)
        struct NeoForgeVersions: Decodable { let versions: [String] }
        let decoded = try JSONDecoder().decode(NeoForgeVersions.self, from: data)
        return decoded.versions
            .filter { $0.hasPrefix(mcVersion.dropFirst(2)) }
            .sorted()
            .reversed()
            .map { String($0) }
    }

    func fetchForgeVersions(for mcVersion: String) async throws -> [String] {
        let urlString = "https://files.minecraftforge.net/net/minecraftforge/forge/promotions_slim.json"
        guard let url = URL(string: urlString) else { throw CurseForgeError.invalidURL }
        let (data, _) = try await session.data(from: url)
        struct ForgePromotions: Decodable { let promos: [String: String] }
        let decoded = try JSONDecoder().decode(ForgePromotions.self, from: data)
        let versions = decoded.promos
            .filter { $0.key.hasPrefix(mcVersion) }
            .map { $0.value }
        return versions.sorted().reversed().map { String($0) }
    }

    func fetchFabricVersions(for mcVersion: String) async throws -> [String] {
        let urlString = "https://meta.fabricmc.net/v2/versions/loader/\(mcVersion)"
        guard let url = URL(string: urlString) else { throw CurseForgeError.invalidURL }
        let (data, _) = try await session.data(from: url)
        struct FabricLoaderEntry: Decodable {
            struct Loader: Decodable { let version: String }
            let loader: Loader
        }
        let entries = try JSONDecoder().decode([FabricLoaderEntry].self, from: data)
        return entries.map { $0.loader.version }
    }
}
