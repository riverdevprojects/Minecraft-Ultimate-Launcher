// NewModpackSheet.swift

import SwiftUI

struct NewModpackSheet: View {
    let onCreated: (Modpack) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var installer = ModLoaderInstaller()
    @StateObject private var vm = NewModpackViewModel()

    @State private var name: String = ""
    @State private var selectedVersion: String = "1.21.1"
    @State private var selectedLoaderType: ModLoaderType = .neoforge
    @State private var selectedLoaderVersion: String = ""
    @State private var iconURL: URL?
    @State private var showIconPicker = false
    @State private var showLoaderProgress = false
    @State private var creationError: Error?
    @State private var showError = false

    static let mcVersions = ["1.21.1", "1.20.1", "1.19.2", "1.18.2", "1.16.5"]

    var body: some View {
        VStack(spacing: 0) {
            formContent
                .padding(24)

            Divider()
            bottomButtons
                .padding(16)
        }
        .frame(minWidth: 460, minHeight: 400)
        .navigationTitle("New Modpack")
        .onAppear {
            vm.fetchLoaderVersions(for: selectedVersion, loader: selectedLoaderType)
        }
        .onChange(of: selectedVersion) { v in
            vm.fetchLoaderVersions(for: v, loader: selectedLoaderType)
        }
        .onChange(of: selectedLoaderType) { t in
            vm.fetchLoaderVersions(for: selectedVersion, loader: t)
        }
        .onChange(of: vm.loaderVersions) { versions in
            selectedLoaderVersion = versions.first ?? ""
        }
        .sheet(isPresented: $showLoaderProgress) {
            ModLoaderProgressSheet(installer: installer)
        }
        .alert("Error", isPresented: $showError, actions: {
            Button("OK") {}
        }, message: {
            Text(creationError?.localizedDescription ?? "")
        })
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            iconSection

            VStack(alignment: .leading, spacing: 6) {
                Label("Modpack Name", systemImage: "textformat")
                    .font(.headline)
                TextField("My Modpack", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Minecraft Version", systemImage: "gamecontroller")
                    .font(.headline)
                Picker("Minecraft Version", selection: $selectedVersion) {
                    ForEach(Self.mcVersions, id: \.self) { v in
                        Text(v).tag(v)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Mod Loader", systemImage: "wrench.and.screwdriver")
                    .font(.headline)
                Picker("Mod Loader", selection: $selectedLoaderType) {
                    ForEach(ModLoaderType.allCases, id: \.self) { loader in
                        Text(loader.displayName).tag(loader)
                    }
                }
                .pickerStyle(.segmented)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Loader Version", systemImage: "tag")
                    .font(.headline)
                if vm.isLoadingVersions {
                    ProgressView("Fetching versions...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if vm.loaderVersions.isEmpty {
                    Text("No versions available")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Loader Version", selection: $selectedLoaderVersion) {
                        ForEach(vm.loaderVersions, id: \.self) { v in
                            Text(v).tag(v)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }

    private var iconSection: some View {
        HStack(spacing: 16) {
            Button {
                showIconPicker = true
            } label: {
                if let iconURL = iconURL, let img = NSImage(contentsOf: iconURL) {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.15))
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                }
            }
            .buttonStyle(.plain)
            .fileImporter(
                isPresented: $showIconPicker,
                allowedContentTypes: [.png, .jpeg],
                allowsMultipleSelection: false
            ) { result in
                if case .success(let urls) = result {
                    iconURL = urls.first
                }
            }

            VStack(alignment: .leading) {
                Text("Modpack Icon")
                    .font(.headline)
                Text("Optional. PNG or JPG.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var bottomButtons: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.escape)

            Spacer()

            Button("Create Modpack") {
                createModpack()
            }
            .buttonStyle(.borderedProminent)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || selectedLoaderVersion.isEmpty)
            .keyboardShortcut(.return)
        }
    }

    private func createModpack() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, !selectedLoaderVersion.isEmpty else { return }

        var modpack = Modpack.makeNew(
            name: trimmedName,
            minecraftVersion: selectedVersion,
            modLoaderType: selectedLoaderType,
            modLoaderVersion: selectedLoaderVersion
        )

        if let iconSrc = iconURL {
            let iconDest = URL(fileURLWithPath: modpack.instanceDirectory)
                .appendingPathComponent("icon.png")
            try? FileManager.default.createDirectory(
                at: URL(fileURLWithPath: modpack.instanceDirectory),
                withIntermediateDirectories: true
            )
            try? FileManager.default.copyItem(at: iconSrc, to: iconDest)
            modpack.iconPath = iconDest.path
        }

        do {
            try FileManager.default.createDirectory(
                at: modpack.modsDirectoryURL,
                withIntermediateDirectories: true
            )
            try DatabaseManager.shared.save(modpack: modpack)
            onCreated(modpack)

            showLoaderProgress = true
            Task {
                await installer.install(
                    modLoaderType: selectedLoaderType,
                    mcVersion: selectedVersion,
                    loaderVersion: selectedLoaderVersion,
                    instanceDirectory: modpack.instanceURL
                )
                showLoaderProgress = false
                dismiss()
            }
        } catch {
            creationError = error
            showError = true
        }
    }
}

// MARK: - NewModpackViewModel

@MainActor
final class NewModpackViewModel: ObservableObject {
    @Published var loaderVersions: [String] = []
    @Published var isLoadingVersions: Bool = false

    private let api = CurseForgeAPIService.shared

    func fetchLoaderVersions(for mcVersion: String, loader: ModLoaderType) {
        isLoadingVersions = true
        loaderVersions = []
        Task {
            do {
                switch loader {
                case .neoforge:
                    loaderVersions = try await api.fetchNeoForgeVersions(for: mcVersion)
                case .forge:
                    loaderVersions = try await api.fetchForgeVersions(for: mcVersion)
                case .fabric:
                    loaderVersions = try await api.fetchFabricVersions(for: mcVersion)
                }
            } catch {
                loaderVersions = []
            }
            isLoadingVersions = false
        }
    }
}
