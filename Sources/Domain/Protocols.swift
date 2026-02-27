import Foundation

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
    func schedule(for subscription: Subscription, daysBefore: Int) async throws
    func rescheduleAll(subscriptions: [Subscription], reminderDays: [Int]) async throws
    func cancel(for subscriptionID: UUID) async
}
