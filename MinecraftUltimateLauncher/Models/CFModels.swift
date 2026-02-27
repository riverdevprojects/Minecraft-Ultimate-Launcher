// CFModels.swift

import Foundation

// MARK: - CurseForge API Response Wrappers

struct CFResponse<T: Codable>: Codable {
    let data: T
}

struct CFPaginatedResponse<T: Codable>: Codable {
    let data: [T]
    let pagination: CFPagination?
}

struct CFPagination: Codable {
    let index: Int
    let pageSize: Int
    let resultCount: Int
    let totalCount: Int
}

// MARK: - CFMod

struct CFMod: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let summary: String
    let downloadCount: Int
    let logo: CFModLogo?
    let categories: [CFCategory]
    let latestFiles: [CFModFile]
    let authors: [CFAuthor]
    let links: CFModLinks?
    let dateModified: String?

    var logoUrl: String? { logo?.url }

    static func == (lhs: CFMod, rhs: CFMod) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct CFModLogo: Codable {
    let id: Int
    let url: String
    let thumbnailUrl: String?
}

struct CFAuthor: Codable {
    let id: Int
    let name: String
    let url: String?
}

struct CFModLinks: Codable {
    let websiteUrl: String?
    let wikiUrl: String?
    let issuesUrl: String?
    let sourceUrl: String?
}

// MARK: - CFModFile

struct CFModFile: Codable, Identifiable, Hashable {
    let id: Int
    let displayName: String
    let fileName: String
    let downloadUrl: String?
    let gameVersions: [String]
    let dependencies: [CFModDependency]
    let fileLength: Int?
    let fileDate: String?

    static func == (lhs: CFModFile, rhs: CFModFile) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - CFCategory

struct CFCategory: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let iconUrl: String?
    let parentCategoryId: Int?

    static func == (lhs: CFCategory, rhs: CFCategory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - CFModDependency

struct CFModDependency: Codable {
    let modId: Int
    let relationType: Int

    var isRequired: Bool { relationType == 1 }
    var isOptional: Bool { relationType == 2 }
}

// MARK: - CurseForge Errors

enum CurseForgeError: LocalizedError {
    case noAPIKey
    case invalidURL
    case httpError(Int)
    case decodingError(Error)
    case noDownloadURL
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No CurseForge API key found. Please set up your API key in Settings."
        case .invalidURL:
            return "Invalid URL constructed for API request."
        case .httpError(let code):
            return "HTTP error \(code) from CurseForge API."
        case .decodingError(let err):
            return "Failed to decode API response: \(err.localizedDescription)"
        case .noDownloadURL:
            return "No download URL available for this file."
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}
