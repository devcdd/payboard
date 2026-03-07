import Foundation
import Domain

public actor NoopNotificationScheduler: NotificationScheduler {
    public init() {}

    @discardableResult
    public func requestPermission() async -> Bool { true }
    public func authorizationStatus() async -> NotificationAuthorizationStatus { .authorized }

    public func schedule(for subscription: Subscription, daysBefore: Int, hour: Int, minute: Int) async throws {}

    public func rescheduleAll(
        subscriptions: [Subscription],
        reminderDays: [Int],
        reminderHour: Int,
        reminderMinute: Int
    ) async throws {}

    public func scheduleTestNotification() async throws {}

    public func cancel(for subscriptionID: UUID) async {}
}
