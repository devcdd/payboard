import Foundation
import SwiftUI
import Domain
import Data

@MainActor
public final class BoardViewModel: ObservableObject {
    @Published public private(set) var subscriptions: [Subscription] = []
    @Published public var selectedFilter: BoardFilter = .all
    @Published public var errorMessage: String?

    private let repository: any SubscriptionRepository
    private let notificationScheduler: any NotificationScheduler
    private var reminderOptions: [ReminderOption] = [.threeDays]
    private var reminderHour: Int = 9
    private var reminderMinute: Int = 0

    public init(
        repository: any SubscriptionRepository = InMemorySubscriptionRepository(seed: SampleData.subscriptions),
        notificationScheduler: any NotificationScheduler = NoopNotificationScheduler()
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
    }

    public var filteredSubscriptions: [Subscription] {
        let calendar = Calendar.current
        let now = Date()

        switch selectedFilter {
        case .all:
            return subscriptions
        case .thisWeek:
            guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: now) else { return subscriptions }
            return subscriptions.filter { $0.nextBillingDate >= now && $0.nextBillingDate <= weekEnd }
        case .thisMonth:
            guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: now) else { return subscriptions }
            return subscriptions.filter { $0.nextBillingDate >= now && $0.nextBillingDate <= monthEnd }
        }
    }

    public func setReminderOptions(_ options: [ReminderOption]) {
        reminderOptions = options
    }

    public func setReminderTime(hour: Int, minute: Int) {
        reminderHour = min(23, max(0, hour))
        reminderMinute = min(59, max(0, minute))
    }

    public func syncReminderOptions(_ options: Set<ReminderOption>, hour: Int, minute: Int) async {
        reminderOptions = Array(options)
        setReminderTime(hour: hour, minute: minute)
        do {
            try await notificationScheduler.rescheduleAll(
                subscriptions: subscriptions,
                reminderDays: reminderOptions.map(\.rawValue),
                reminderHour: reminderHour,
                reminderMinute: reminderMinute
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func onAppear() async {
        await reload()
    }

    public func reload() async {
        do {
            subscriptions = try await repository.fetchAll()
            WidgetSnapshotStore.save(subscriptions: subscriptions)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func upsert(_ subscription: Subscription) async {
        do {
            if subscriptions.contains(where: { $0.id == subscription.id }) {
                try await repository.update(subscription)
            } else {
                try await repository.create(subscription)
            }

            await notificationScheduler.cancel(for: subscription.id)
            guard subscription.isActive && subscription.notificationsEnabled else {
                await reload()
                return
            }

            for option in reminderOptions {
                try await notificationScheduler.schedule(
                    for: subscription,
                    daysBefore: option.rawValue,
                    hour: reminderHour,
                    minute: reminderMinute
                )
            }

            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func delete(_ subscription: Subscription) async {
        do {
            try await repository.delete(id: subscription.id)
            await notificationScheduler.cancel(for: subscription.id)
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func markPaymentComplete(_ subscription: Subscription) async {
        let completed = completedSubscription(from: subscription)
        await saveAndReschedule(updatedSubscriptions: [completed])
    }

    public func markPaymentComplete(ids: Set<UUID>) async {
        let updates = subscriptions
            .filter { ids.contains($0.id) }
            .map { completedSubscription(from: $0) }
        await saveAndReschedule(updatedSubscriptions: updates)
    }

    public func updateNextBillingDate(ids: Set<UUID>, to date: Date) async {
        guard !ids.isEmpty else { return }
        let updates = subscriptions
            .filter { ids.contains($0.id) }
            .map { subscription in
                var copy = subscription
                copy.nextBillingDate = date
                copy.updatedAt = .now
                return copy
            }
        await saveAndReschedule(updatedSubscriptions: updates)
    }

    public func delete(ids: Set<UUID>) async {
        guard !ids.isEmpty else { return }
        do {
            for id in ids {
                try await repository.delete(id: id)
                await notificationScheduler.cancel(for: id)
            }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func completedSubscription(from subscription: Subscription) -> Subscription {
        var copy = subscription
        copy.lastPaymentDate = .now
        copy.nextBillingDate = nextBillingDate(after: subscription.nextBillingDate, cycle: subscription.billingCycle)
        copy.updatedAt = .now
        return copy
    }

    private func nextBillingDate(after date: Date, cycle: BillingCycle) -> Date {
        let calendar = Calendar.current
        switch cycle {
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: date) ?? date
        case let .customDays(days):
            return calendar.date(byAdding: .day, value: max(1, days), to: date) ?? date
        }
    }

    private func saveAndReschedule(updatedSubscriptions: [Subscription]) async {
        guard !updatedSubscriptions.isEmpty else { return }
        do {
            for subscription in updatedSubscriptions {
                try await repository.update(subscription)
                await notificationScheduler.cancel(for: subscription.id)
                guard subscription.isActive && subscription.notificationsEnabled else { continue }
                for option in reminderOptions {
                    try await notificationScheduler.schedule(
                        for: subscription,
                        daysBefore: option.rawValue,
                        hour: reminderHour,
                        minute: reminderMinute
                    )
                }
            }
            await reload()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
