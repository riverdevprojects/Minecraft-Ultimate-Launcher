// MainContentView.swift

import SwiftUI

struct MainContentView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var modpacks = ModpackListViewModel()
    @State private var selectedMod: CFMod?
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(modpacks: modpacks)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } content: {
            contentView
                .navigationSplitViewColumnWidth(min: 400, ideal: 550)
        } detail: {
            InspectorView(selectedMod: selectedMod)
                .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 380)
        }
        .sheet(isPresented: $appState.showNewModpackSheet) {
            NewModpackSheet { newModpack in
                modpacks.refresh()
            }
        }
        .onAppear {
            modpacks.refresh()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch appState.navigationSelection {
        case .modpack(let modpack):
            ModpackDetailView(
                modpack: modpack,
                modpacks: modpacks,
                selectedMod: $selectedMod
            )
        case .browseMods:
            ModBrowserView(
                selectedModpack: appState.selectedModpack,
                selectedMod: $selectedMod
            )
        case nil:
            emptySelectionView
        }
    }

    private var emptySelectionView: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("Select a modpack or browse mods")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - ModpackListViewModel

@MainActor
final class ModpackListViewModel: ObservableObject {
    @Published var modpacks: [Modpack] = []
    @Published var error: Error?

    func refresh() {
        do {
            modpacks = try DatabaseManager.shared.fetchAllModpacks()
        } catch {
            self.error = error
        }
    }

    func delete(_ modpack: Modpack) {
        do {
            try DatabaseManager.shared.delete(modpack: modpack)
            try? FileManager.default.removeItem(at: modpack.instanceURL)
            refresh()
        } catch {
            self.error = error
        }
    }

    func modCount(for modpack: Modpack) -> Int {
        (try? DatabaseManager.shared.modCount(for: modpack.id)) ?? 0
    }
}
