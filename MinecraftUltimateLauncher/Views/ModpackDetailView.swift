// ModpackDetailView.swift

import SwiftUI

struct ModpackDetailView: View {
    let modpack: Modpack
    @ObservedObject var modpacks: ModpackListViewModel
    @Binding var selectedMod: CFMod?

    @StateObject private var vm = ModpackDetailViewModel()
    @StateObject private var launcher = MinecraftLauncher()
    @StateObject private var exporter = ModpackExporter()

    @State private var showAddMods = false
    @State private var showLaunchError = false
    @State private var showExportError = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            modList
        }
        .navigationTitle(modpack.name)
        .task {
            vm.load(for: modpack)
        }
        .onChange(of: modpack) { _, newPack in
            vm.load(for: newPack)
        }
        .alert("Launch Error", isPresented: $showLaunchError, actions: {
            Button("OK") {}
        }, message: {
            Text(launcher.error?.localizedDescription ?? "Unknown error")
        })
        .alert("Export Error", isPresented: $showExportError, actions: {
            Button("OK") {}
        }, message: {
            Text(exporter.error?.localizedDescription ?? "Unknown error")
        })
        .fileImporter(
            isPresented: .constant(exportURL != nil),
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { _ in exportURL = nil }
        .sheet(isPresented: $showAddMods) {
            NavigationStack {
                ModBrowserView(
                    selectedModpack: modpack,
                    selectedMod: .constant(nil),
                    onModInstalled: {
                        vm.load(for: modpack)
                        modpacks.refresh()
                    }
                )
                .navigationTitle("Add Mods to \(modpack.name)")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { showAddMods = false }
                    }
                }
            }
            .frame(minWidth: 700, minHeight: 500)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                showAddMods = true
            } label: {
                Label("Add Mods", systemImage: "plus.circle")
            }

            Button {
                Task {
                    await launcher.launch(modpack: modpack)
                    if launcher.error != nil { showLaunchError = true }
                }
            } label: {
                Label("Launch", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(launcher.isLaunching)

            Button {
                Task {
                    if let url = await exporter.export(modpack: modpack, mods: vm.mods) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } else if exporter.error != nil {
                        showExportError = true
                    }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(exporter.isExporting)

            Spacer()

            if launcher.isLaunching {
                ProgressView()
                    .scaleEffect(0.6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var modList: some View {
        Group {
            if vm.isLoading {
                ProgressView("Loading mods...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.mods.isEmpty {
                emptyModsView
            } else {
                List(vm.mods) { mod in
                    InstalledModRow(
                        mod: mod,
                        onToggle: { isEnabled in
                            vm.toggle(mod: mod, isEnabled: isEnabled, modpack: modpack)
                            modpacks.refresh()
                        },
                        onRemove: {
                            vm.remove(mod: mod, from: modpack)
                            modpacks.refresh()
                        }
                    )
                }
                .listStyle(.inset)
            }
        }
    }

    private var emptyModsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece.extension")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No mods installed")
                .font(.title3)
                .foregroundStyle(.secondary)
            Button("Add Mods") { showAddMods = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - InstalledModRow

struct InstalledModRow: View {
    let mod: InstalledMod
    let onToggle: (Bool) -> Void
    let onRemove: () -> Void

    @State private var isEnabled: Bool

    init(mod: InstalledMod, onToggle: @escaping (Bool) -> Void, onRemove: @escaping () -> Void) {
        self.mod = mod
        self.onToggle = onToggle
        self.onRemove = onRemove
        _isEnabled = State(initialValue: mod.isEnabled)
    }

    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .onChange(of: isEnabled) { _, val in onToggle(val) }

            VStack(alignment: .leading, spacing: 2) {
                Text(mod.name)
                    .font(.body)
                    .strikethrough(!isEnabled, color: .secondary)
                Text(mod.version)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onRemove()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Remove mod")
        }
        .padding(.vertical, 4)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - ModpackDetailViewModel

@MainActor
final class ModpackDetailViewModel: ObservableObject {
    @Published var mods: [InstalledMod] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    func load(for modpack: Modpack) {
        isLoading = true
        do {
            mods = try DatabaseManager.shared.fetchMods(for: modpack.id)
        } catch {
            self.error = error
        }
        isLoading = false
    }

    func toggle(mod: InstalledMod, isEnabled: Bool, modpack: Modpack) {
        do {
            try DatabaseManager.shared.updateEnabled(modId: mod.id, isEnabled: isEnabled)
            toggleModFile(mod: mod, isEnabled: isEnabled, modpack: modpack)
            load(for: modpack)
        } catch {
            self.error = error
        }
    }

    func remove(mod: InstalledMod, from modpack: Modpack) {
        do {
            try DatabaseManager.shared.delete(installedMod: mod)
            let modFile = modpack.modsDirectoryURL.appendingPathComponent(mod.fileName)
            try? FileManager.default.removeItem(at: modFile)
            load(for: modpack)
        } catch {
            self.error = error
        }
    }

    private func toggleModFile(mod: InstalledMod, isEnabled: Bool, modpack: Modpack) {
        let activeFile = modpack.modsDirectoryURL.appendingPathComponent(mod.fileName)
        let disabledFile = modpack.modsDirectoryURL.appendingPathComponent(mod.fileName + ".disabled")

        if isEnabled {
            try? FileManager.default.moveItem(at: disabledFile, to: activeFile)
        } else {
            try? FileManager.default.moveItem(at: activeFile, to: disabledFile)
        }
    }
}
