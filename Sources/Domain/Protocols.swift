import Foundation

public enum NotificationAuthorizationStatus: Sendable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
}

public protocol SubscriptionRepository: Sendable {
    func fetchAll() async throws -> [Subscription]
    func create(_ subscription: Subscription) async throws
    func update(_ subscription: Subscription) async throws
    func delete(id: UUID) async throws
    func upcoming(within days: Int, from now: Date) async throws -> [Subscription]
}

public protocol NotificationScheduler: Sendable {
    @discardableResult
    func requestPermission() async -> Bool
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func schedule(for subscription: Subscription, daysBefore: Int, hour: Int, minute: Int) async throws
    func rescheduleAll(
        subscriptions: [Subscription],
        reminderDays: [Int],
        reminderHour: Int,
        reminderMinute: Int
    ) async throws
    func scheduleTestNotification() async throws
    func cancel(for subscriptionID: UUID) async
}
