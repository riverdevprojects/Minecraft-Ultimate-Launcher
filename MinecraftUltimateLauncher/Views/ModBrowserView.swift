// ModBrowserView.swift

import SwiftUI
import Combine

struct ModBrowserView: View {
    let selectedModpack: Modpack?
    @Binding var selectedMod: CFMod?
    var onModInstalled: (() -> Void)?

    @StateObject private var vm = ModBrowserViewModel()
    @State private var searchText: String = ""
    @State private var selectedVersion: String = "1.21.1"
    @State private var selectedCategory: CFCategory?
    @State private var debounceCancellable: AnyCancellable?

    static let mcVersions = ["1.21.1", "1.20.1", "1.19.2", "1.18.2", "1.16.5"]

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            resultsList
        }
        .onAppear {
            vm.loadCategories()
            triggerSearch()
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search mods...", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _ in scheduleSearch() }

            Divider().frame(height: 20)

            Picker("Version", selection: $selectedVersion) {
                ForEach(Self.mcVersions, id: \.self) { v in
                    Text(v).tag(v)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
            .onChange(of: selectedVersion) { _ in triggerSearch() }

            Picker("Category", selection: $selectedCategory) {
                Text("All Categories").tag(Optional<CFCategory>.none)
                ForEach(vm.categories) { cat in
                    Text(cat.name).tag(Optional(cat))
                }
            }
            .pickerStyle(.menu)
            .frame(width: 160)
            .onChange(of: selectedCategory) { _ in triggerSearch() }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var resultsList: some View {
        Group {
            if vm.isLoading && vm.mods.isEmpty {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if vm.mods.isEmpty && !vm.isLoading {
                emptyResultsView
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(vm.mods) { mod in
                            ModCardView(
                                mod: mod,
                                selectedModpack: selectedModpack,
                                gameVersion: selectedVersion,
                                isSelected: selectedMod?.id == mod.id,
                                onInstalled: onModInstalled
                            )
                            .onTapGesture { selectedMod = mod }
                            .onAppear {
                                if mod.id == vm.mods.last?.id {
                                    vm.loadNextPage(
                                        query: searchText,
                                        gameVersion: selectedVersion,
                                        categoryId: selectedCategory?.id
                                    )
                                }
                            }
                        }

                        if vm.isLoading {
                            ProgressView()
                                .padding()
                        }
                    }
                    .padding(12)
                }
            }
        }
        .alert("Error", isPresented: .constant(vm.error != nil), actions: {
            Button("OK") { vm.error = nil }
        }, message: {
            Text(vm.error?.localizedDescription ?? "")
        })
    }

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text(searchText.isEmpty ? "Enter a search term to find mods" : "No mods found")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func scheduleSearch() {
        debounceCancellable?.cancel()
        debounceCancellable = Just(())
            .delay(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { _ in triggerSearch() }
    }

    private func triggerSearch() {
        vm.search(
            query: searchText,
            gameVersion: selectedVersion,
            categoryId: selectedCategory?.id
        )
    }
}

// MARK: - ModBrowserViewModel

@MainActor
final class ModBrowserViewModel: ObservableObject {
    @Published var mods: [CFMod] = []
    @Published var categories: [CFCategory] = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private var currentPage = 0
    private var hasMore = true
    private var currentQuery = ""
    private var currentVersion: String?
    private var currentCategoryId: Int?
    private let pageSize = 20
    private var searchTask: Task<Void, Never>?

    private let api = CurseForgeAPIService.shared

    func loadCategories() {
        Task {
            do {
                categories = try await api.getCategories()
                    .filter { $0.parentCategoryId == nil || $0.parentCategoryId == 0 }
            } catch {
                // categories failure is non-fatal
            }
        }
    }

    func search(query: String, gameVersion: String?, categoryId: Int?) {
        searchTask?.cancel()
        mods = []
        currentPage = 0
        hasMore = true
        currentQuery = query
        currentVersion = gameVersion
        currentCategoryId = categoryId

        searchTask = Task {
            await fetchPage()
        }
    }

    func loadNextPage(query: String, gameVersion: String?, categoryId: Int?) {
        guard !isLoading && hasMore else { return }
        Task { await fetchPage() }
    }

    private func fetchPage() async {
        guard !isLoading && hasMore else { return }
        isLoading = true
        do {
            let results = try await api.searchMods(
                query: currentQuery,
                gameVersion: currentVersion,
                categoryId: currentCategoryId,
                pageSize: pageSize,
                index: currentPage * pageSize
            )
            if !Task.isCancelled {
                mods.append(contentsOf: results)
                currentPage += 1
                hasMore = results.count == pageSize
            }
        } catch {
            if !Task.isCancelled {
                self.error = error
            }
        }
        isLoading = false
    }
}
