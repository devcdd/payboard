import SwiftUI
import AppCore
import Features

@main
struct PayBoardApp: App {
    private enum AppTab: Hashable {
        case board
        case calendar
        case archive
        case settings
    }

    private let environment: AppEnvironment

    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var boardViewModel: BoardViewModel
    @State private var selectedTab: AppTab

    init() {
        let environment = AppEnvironment.live()
        self.environment = environment
        _settingsViewModel = StateObject(
            wrappedValue: SettingsViewModel(
                scheduler: environment.notificationScheduler,
                repository: environment.repository
            )
        )
        _boardViewModel = StateObject(wrappedValue: BoardViewModel(
            repository: environment.repository,
            notificationScheduler: environment.notificationScheduler
        ))
        let storedInitialScreen = UserDefaults.standard.string(forKey: "settings.initialScreen")
        _selectedTab = State(initialValue: storedInitialScreen == "calendar" ? .calendar : .board)
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                BoardView(viewModel: boardViewModel, settingsViewModel: settingsViewModel, displayMode: .board)
                    .tabItem {
                        Label("tab.board", systemImage: "square.grid.2x2")
                    }
                    .tag(AppTab.board)

                BoardView(viewModel: boardViewModel, settingsViewModel: settingsViewModel, displayMode: .calendar)
                    .tabItem {
                        Label("tab.calendar", systemImage: "calendar")
                    }
                    .tag(AppTab.calendar)

                ArchiveView(viewModel: boardViewModel)
                    .tabItem {
                        Label("tab.archive", systemImage: "archivebox")
                    }
                    .tag(AppTab.archive)

                SettingsView(viewModel: settingsViewModel)
                    .tabItem {
                        Label("tab.settings", systemImage: "gearshape")
                    }
                    .tag(AppTab.settings)
            }
            .preferredColorScheme(settingsViewModel.preferredColorScheme)
            .environment(\.locale, settingsViewModel.preferredLocale)
        }
    }
}
