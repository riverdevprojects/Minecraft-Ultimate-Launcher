// MinecraftUltimateLauncherApp.swift

import SwiftUI

@main
struct MinecraftUltimateLauncherApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .appSettings) {
                Button("Settings...") {
                    appState.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {
    @Published var isOnboardingComplete: Bool = false
    @Published var selectedModpack: Modpack?
    @Published var showSettings: Bool = false
    @Published var showNewModpackSheet: Bool = false
    @Published var navigationSelection: SidebarItem? = nil

    init() {
        let key = KeychainService.shared.load(
            service: KeychainService.serviceName,
            account: KeychainService.apiKeyAccount
        )
        isOnboardingComplete = (key != nil && !key!.isEmpty)
    }

    func completeOnboarding() {
        isOnboardingComplete = true
    }
}

// MARK: - SidebarItem

enum SidebarItem: Hashable {
    case modpack(Modpack)
    case browseMods
}

// MARK: - RootView

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        if appState.isOnboardingComplete {
            MainContentView()
        } else {
            OnboardingView()
        }
    }
}
