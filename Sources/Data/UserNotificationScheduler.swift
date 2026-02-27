import Foundation
import Domain
import UserNotifications

public actor UserNotificationScheduler: NotificationScheduler {
    public init() {}

    @discardableResult
    public func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    public func schedule(for subscription: Subscription, daysBefore: Int) async throws {
        let fireDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: subscription.nextBillingDate)
            ?? subscription.nextBillingDate
        let normalizedDate = Self.setHour(fireDate, hour: 9)
        guard normalizedDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "결제 예정 알림"
        content.body = "\(subscription.name) 결제가 곧 예정되어 있습니다."
        content.sound = .default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: normalizedDate)
        let request = UNNotificationRequest(
            identifier: Self.notificationID(subscriptionID: subscription.id, daysBefore: daysBefore),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    public func rescheduleAll(subscriptions: [Subscription], reminderDays: [Int]) async throws {
        let center = UNUserNotificationCenter.current()
        let ids = subscriptions.flatMap { subscription in
            reminderDays.map { days in Self.notificationID(subscriptionID: subscription.id, daysBefore: days) }
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)

        for subscription in subscriptions where subscription.isActive {
            for days in reminderDays {
                try await schedule(for: subscription, daysBefore: days)
            }
        }
    }

    public func cancel(for subscriptionID: UUID) async {
        let center = UNUserNotificationCenter.current()
        let ids = ReminderOption.allCases.map { Self.notificationID(subscriptionID: subscriptionID, daysBefore: $0.rawValue) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    private static func notificationID(subscriptionID: UUID, daysBefore: Int) -> String {
        "subscription.\(subscriptionID.uuidString).\(daysBefore)"
    }

    private static func setHour(_ date: Date, hour: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = 0
        components.second = 0
        return Calendar.current.date(from: components) ?? date
    }
}
