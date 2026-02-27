import Foundation
import Domain
import Data

public struct AppEnvironment: Sendable {
    public let repository: any SubscriptionRepository
    public let notificationScheduler: any NotificationScheduler

    public init(
        repository: any SubscriptionRepository,
        notificationScheduler: any NotificationScheduler
    ) {
        self.repository = repository
        self.notificationScheduler = notificationScheduler
    }

    public static func live() -> AppEnvironment {
        AppEnvironment(
            repository: FileSubscriptionRepository(),
            notificationScheduler: UserNotificationScheduler()
        )
    }
}
