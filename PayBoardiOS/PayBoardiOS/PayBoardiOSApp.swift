import SwiftUI
import AppCore
import Features
import UserNotifications

@main
struct PayBoardiOSApp: App {
    private let environment: AppEnvironment

    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var boardViewModel: BoardViewModel

    init() {
        let environment = AppEnvironment.live()
        self.environment = environment
        NotificationPresentationDelegate.configure()
        _settingsViewModel = StateObject(
            wrappedValue: SettingsViewModel(
                scheduler: environment.notificationScheduler,
                repository: environment.repository
            )
        )
        _boardViewModel = StateObject(
            wrappedValue: BoardViewModel(
                repository: environment.repository,
                notificationScheduler: environment.notificationScheduler
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                BoardView(viewModel: boardViewModel, settingsViewModel: settingsViewModel, displayMode: .board)
                    .tabItem { Label("tab.board", systemImage: "square.grid.2x2") }

                BoardView(viewModel: boardViewModel, settingsViewModel: settingsViewModel, displayMode: .calendar)
                    .tabItem { Label("tab.calendar", systemImage: "calendar") }

                SettingsView(viewModel: settingsViewModel)
                    .tabItem { Label("tab.settings", systemImage: "gearshape") }
            }
            .preferredColorScheme(settingsViewModel.preferredColorScheme)
            .environment(\.locale, settingsViewModel.preferredLocale)
        }
    }
}

private final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private static let shared = NotificationPresentationDelegate()

    static func configure() {
        UNUserNotificationCenter.current().delegate = shared
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge, .list]
    }
}
