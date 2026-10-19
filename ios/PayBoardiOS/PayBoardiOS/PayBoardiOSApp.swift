import SwiftUI
import AppCore
import BackgroundTasks
import Features
import UserNotifications

@main
struct PayBoardiOSApp: App {
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
    @Environment(\.scenePhase) private var scenePhase

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
        let storedInitialScreen = UserDefaults.standard.string(forKey: "settings.initialScreen")
        _selectedTab = State(initialValue: storedInitialScreen == "calendar" ? .calendar : .board)
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                BoardView(viewModel: boardViewModel, settingsViewModel: settingsViewModel, displayMode: .board)
                    .tabItem { Label("tab.board", systemImage: "square.grid.2x2") }
                    .tag(AppTab.board)

                BoardView(viewModel: boardViewModel, settingsViewModel: settingsViewModel, displayMode: .calendar)
                    .tabItem { Label("tab.calendar", systemImage: "calendar") }
                    .tag(AppTab.calendar)

                ArchiveView(viewModel: boardViewModel, settingsViewModel: settingsViewModel)
                    .tabItem { Label("tab.archive", systemImage: "archivebox") }
                    .tag(AppTab.archive)

                SettingsView(viewModel: settingsViewModel)
                    .tabItem { Label("tab.settings", systemImage: "gearshape") }
                    .tag(AppTab.settings)
            }
            .preferredColorScheme(settingsViewModel.preferredColorScheme)
            .environment(\.locale, settingsViewModel.preferredLocale)
            .alert("settings.backup.signIn.restorePrompt.title", isPresented: $settingsViewModel.isShowingRestorePromptAfterSignIn) {
                Button("settings.backup.signIn.restorePrompt.skip", role: .cancel) {
                    settingsViewModel.skipRestoreAfterSignIn()
                }
                Button("settings.backup.signIn.restorePrompt.restore", role: .destructive) {
                    Task { await settingsViewModel.confirmRestoreAfterSignIn() }
                }
            } message: {
                Text("settings.backup.signIn.restorePrompt.message")
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                BackgroundRefresh.schedule()
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            BackgroundRefresh.schedule()
            await refreshInBackground()
        }
    }

    // 백그라운드 실행에서는 BoardView.task 가 돌지 않아 알림 설정을 먼저 맞춰야 자동결제 재예약이 기본값으로 덮이지 않음
    private func refreshInBackground() async {
        boardViewModel.setReminderOptions(Array(settingsViewModel.effectiveReminderOptions))
        boardViewModel.setReminderTime(hour: settingsViewModel.reminderHour, minute: settingsViewModel.reminderMinute)
        await boardViewModel.onAppear()
    }
}

// 위젯이 스스로 결제일을 넘겨 보여주는 것의 보조 수단. 실행 시점은 시스템이 정하고 보장되지 않는다
private enum BackgroundRefresh {
    nonisolated static let identifier = "kr.co.cdd.PayBoardiOS.refresh"

    nonisolated static func schedule() {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        let calendar = Calendar.current
        request.earliestBeginDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: .now))
        try? BGTaskScheduler.shared.submit(request)
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
