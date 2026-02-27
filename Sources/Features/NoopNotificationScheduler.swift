import Foundation
import Domain

public actor NoopNotificationScheduler: NotificationScheduler {
    public init() {}

    @discardableResult
    public func requestPermission() async -> Bool { true }

    public func schedule(for subscription: Subscription, daysBefore: Int) async throws {}

    public func rescheduleAll(subscriptions: [Subscription], reminderDays: [Int]) async throws {}

    public func cancel(for subscriptionID: UUID) async {}
}
