import Foundation
import SwiftUI
import Domain
import Data

@MainActor
public final class BoardViewModel: ObservableObject {
    @Published public private(set) var subscriptions: [Subscription] = []
    @Published public var selectedFilter: BoardFilter = .all
    @Published public var isPresentingEditor = false
    @Published public var editingTarget: Subscription?
    @Published public var errorMessage: String?

    private let repository: any SubscriptionRepository
    private let notificationScheduler: any NotificationScheduler
    private var reminderOptions: [ReminderOption] = [.threeDays]

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

    public func syncReminderOptions(_ options: Set<ReminderOption>) async {
        reminderOptions = Array(options)
        do {
            try await notificationScheduler.rescheduleAll(
                subscriptions: subscriptions,
                reminderDays: reminderOptions.map(\.rawValue)
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

            for option in reminderOptions {
                try await notificationScheduler.schedule(for: subscription, daysBefore: option.rawValue)
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
}
