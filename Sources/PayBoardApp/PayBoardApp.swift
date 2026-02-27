import SwiftUI
import AppCore
import Features

@main
struct PayBoardApp: App {
    private let environment: AppEnvironment

    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var boardViewModel: BoardViewModel

    init() {
        let environment = AppEnvironment.live()
        self.environment = environment
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(scheduler: environment.notificationScheduler))
        _boardViewModel = StateObject(wrappedValue: BoardViewModel(
            repository: environment.repository,
            notificationScheduler: environment.notificationScheduler
        ))
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                BoardView(viewModel: boardViewModel, settingsViewModel: settingsViewModel)
                    .tabItem {
                        Label("보드", systemImage: "square.grid.2x2")
                    }

                SettingsView(viewModel: settingsViewModel)
                    .tabItem {
                        Label("설정", systemImage: "gearshape")
                    }
            }
        }
    }
}
