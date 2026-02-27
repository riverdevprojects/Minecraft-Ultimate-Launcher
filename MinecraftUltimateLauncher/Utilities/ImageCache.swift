// ImageCache.swift

import SwiftUI
import Foundation

// MARK: - ImageCache

final class ImageCache {
    static let shared = ImageCache()
    private var cache = NSCache<NSString, NSImage>()
    private init() {
        cache.countLimit = 200
    }

    func image(for url: String) -> NSImage? {
        cache.object(forKey: url as NSString)
    }

    func set(image: NSImage, for url: String) {
        cache.setObject(image, forKey: url as NSString)
    }
}

// MARK: - CachedAsyncImage

struct CachedAsyncImage: View {
    let url: String?
    var placeholder: Image = Image(systemName: "photo")
    var contentMode: ContentMode = .fit

    @State private var nsImage: NSImage?
    @State private var isLoading: Bool = false

    var body: some View {
        Group {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .foregroundColor(.secondary)
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let urlString = url, !urlString.isEmpty else { return }

        if let cached = ImageCache.shared.image(for: urlString) {
            nsImage = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        guard let url = URL(string: urlString) else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let image = NSImage(data: data) {
                ImageCache.shared.set(image: image, for: urlString)
                nsImage = image
            }
        } catch {
            // silently fail — placeholder stays
        }
    }
}
