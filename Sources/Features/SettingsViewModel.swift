import Foundation
import Domain

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var selectedOptions: Set<ReminderOption> = [.threeDays]
    @Published public private(set) var permissionGranted = false

    private let scheduler: any NotificationScheduler

    public init(scheduler: any NotificationScheduler = NoopNotificationScheduler()) {
        self.scheduler = scheduler
    }

    public func requestPermission() async {
        permissionGranted = await scheduler.requestPermission()
    }

    public var reminderDays: [Int] {
        selectedOptions.map(\.rawValue).sorted(by: >)
    }
}
