// InspectorView.swift

import SwiftUI

struct InspectorView: View {
    let selectedMod: CFMod?

    var body: some View {
        Group {
            if let mod = selectedMod {
                modDetailContent(mod: mod)
            } else {
                emptyInspector
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyInspector: some View {
        VStack(spacing: 12) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Select a mod to see details")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func modDetailContent(mod: CFMod) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CachedAsyncImage(url: mod.logoUrl)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 6) {
                    Text(mod.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    if let author = mod.authors.first {
                        Text("by \(mod.authors.map(\.name).joined(separator: ", "))")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Text(mod.summary)
                    .font(.body)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Label(formatDownloads(mod.downloadCount), systemImage: "arrow.down.circle.fill")
                        .font(.callout)
                    if let updated = mod.dateModified {
                        Label("Updated: \(updated.prefix(10))", systemImage: "clock")
                            .font(.callout)
                    }
                }

                if !mod.categories.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Categories")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        FlowLayout(spacing: 6) {
                            ForEach(mod.categories) { cat in
                                Text(cat.name)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.accentColor.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                if let links = mod.links {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Links")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if let web = links.websiteUrl, let url = URL(string: web) {
                            Link("Website", destination: url)
                                .font(.callout)
                        }
                        if let wiki = links.wikiUrl, let url = URL(string: wiki) {
                            Link("Wiki", destination: url)
                                .font(.callout)
                        }
                        if let source = links.sourceUrl, let url = URL(string: source) {
                            Link("Source", destination: url)
                                .font(.callout)
                        }
                        if let issues = links.issuesUrl, let url = URL(string: issues) {
                            Link("Issues", destination: url)
                                .font(.callout)
                        }
                    }
                }

                if !mod.latestFiles.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Compatible Versions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        ForEach(mod.latestFiles.prefix(5)) { file in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.displayName)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(file.gameVersions.prefix(3).joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let length = file.fileLength {
                                    Text(formatBytes(length))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                }

                Spacer(minLength: 20)
            }
            .padding(14)
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

    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1024)
    }
}

// MARK: - FlowLayout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var row: CGFloat = 0
        var x: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 {
                x = 0
                height += row + spacing
                row = 0
            }
            x += size.width + spacing
            row = max(row, size.height)
        }
        height += row
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
