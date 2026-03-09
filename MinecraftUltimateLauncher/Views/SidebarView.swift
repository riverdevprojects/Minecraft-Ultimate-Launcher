// SidebarView.swift

import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var modpacks: ModpackListViewModel

    var body: some View {
        List(selection: $appState.navigationSelection) {
            modpacksSection
        }
        .listStyle(.sidebar)
        .navigationTitle("Minecraft Launcher")
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .alert("Error", isPresented: .constant(modpacks.error != nil), actions: {
            Button("OK") { modpacks.error = nil }
        }, message: {
            Text(modpacks.error?.localizedDescription ?? "")
        })
    }

    private var modpacksSection: some View {
        Section("My Modpacks") {
            ForEach(modpacks.modpacks) { modpack in
                SidebarModpackRow(modpack: modpack, modCount: modpacks.modCount(for: modpack))
                    .tag(SidebarItem.modpack(modpack))
                    .contextMenu {
                        Button(role: .destructive) {
                            modpacks.delete(modpack)
                            if appState.navigationSelection == .modpack(modpack) {
                                appState.navigationSelection = nil
                                appState.selectedModpack = nil
                            }
                        } label: {
                            Label("Delete Modpack", systemImage: "trash")
                        }
                    }
            }

            if modpacks.modpacks.isEmpty {
                Text("No modpacks yet")
                    .foregroundStyle(.tertiary)
                    .font(.caption)
            }

            Button {
                appState.navigationSelection = .browseMods
                appState.selectedModpack = nil
            } label: {
                Label("Browse Mods", systemImage: "magnifyingglass")
            }
            .tag(SidebarItem.browseMods)
            .buttonStyle(.plain)
        }
        .onChange(of: appState.navigationSelection) { newValue in
            if case .modpack(let mp) = newValue {
                appState.selectedModpack = mp
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Button {
                appState.showNewModpackSheet = true
            } label: {
                Label("New Modpack", systemImage: "plus")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .help("Create new modpack")
            Spacer()
        }
        .padding(8)
        .background(.bar)
    }
}

// MARK: - SidebarModpackRow

struct SidebarModpackRow: View {
    let modpack: Modpack
    let modCount: Int

    var body: some View {
        HStack(spacing: 10) {
            if let iconPath = modpack.iconPath,
               let img = NSImage(contentsOfFile: iconPath) {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.accent)
                    }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(modpack.name)
                    .font(.body)
                    .lineLimit(1)
                Text("\(modpack.minecraftVersion) · \(modCount) mods")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
