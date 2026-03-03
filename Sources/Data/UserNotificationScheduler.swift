import Foundation
import Domain
import UserNotifications

public actor UserNotificationScheduler: NotificationScheduler {
    private static let appLanguageDefaultsKey = "settings.appLanguage"

    public init() {}

    @discardableResult
    public func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    public func authorizationStatus() async -> NotificationAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let status: NotificationAuthorizationStatus
                switch settings.authorizationStatus {
                case .notDetermined:
                    status = .notDetermined
                case .denied:
                    status = .denied
                case .authorized:
                    status = .authorized
                case .provisional:
                    status = .provisional
                case .ephemeral:
                    status = .ephemeral
                @unknown default:
                    status = .denied
                }
                continuation.resume(returning: status)
            }
        }
    }

    public func schedule(for subscription: Subscription, daysBefore: Int, hour: Int, minute: Int) async throws {
        guard subscription.isActive, subscription.notificationsEnabled else { return }

        let fireDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: subscription.nextBillingDate)
            ?? subscription.nextBillingDate
        let normalizedDate = Self.setTime(fireDate, hour: hour, minute: minute)
        guard normalizedDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = Self.localized("notification.title")
        let bodyFormat = Self.localized("notification.body")
        content.body = String(format: bodyFormat, subscription.name)
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: normalizedDate)
        let request = UNNotificationRequest(
            identifier: Self.notificationID(subscriptionID: subscription.id, daysBefore: daysBefore),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    public func rescheduleAll(
        subscriptions: [Subscription],
        reminderDays: [Int],
        reminderHour: Int,
        reminderMinute: Int
    ) async throws {
        let center = UNUserNotificationCenter.current()
        let ids = subscriptions.flatMap { subscription in
            ReminderOption.allCases.map { option in
                Self.notificationID(subscriptionID: subscription.id, daysBefore: option.rawValue)
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        for subscription in subscriptions where subscription.isActive && subscription.notificationsEnabled {
            for days in reminderDays {
                try await schedule(
                    for: subscription,
                    daysBefore: days,
                    hour: reminderHour,
                    minute: reminderMinute
                )
            }
        }
    }

    public func scheduleTestNotification() async throws {
        let content = UNMutableNotificationContent()
        content.title = Self.localized("notification.test.title")
        content.body = Self.localized("notification.test.body")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "subscription.test.reminder",
            content: content,
            trigger: nil
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["subscription.test.reminder"])
        try await center.add(request)
    }

    public func cancel(for subscriptionID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let ids = ReminderOption.allCases.map { Self.notificationID(subscriptionID: subscriptionID, daysBefore: $0.rawValue) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func notificationID(subscriptionID: UUID, daysBefore: Int) -> String {
        "subscription.\(subscriptionID.uuidString).\(daysBefore)"
    }

    private static func setTime(_ date: Date, hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components) ?? date
    }

    private static func localized(_ key: String) -> String {
        let selectedLanguageCode = UserDefaults.standard.string(forKey: appLanguageDefaultsKey) ?? "ko"

        if let path = Bundle.main.path(forResource: selectedLanguageCode, ofType: "lproj"),
           let languageBundle = Bundle(path: path) {
            return languageBundle.localizedString(forKey: key, value: key, table: nil)
        }

        return NSLocalizedString(key, comment: "")
    }
}
