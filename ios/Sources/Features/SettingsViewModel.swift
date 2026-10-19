import Foundation
import SwiftUI
import Domain
import Data
import AuthenticationServices
import CryptoKit
import Security
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public enum AppAppearance: String, CaseIterable, Sendable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .system:
            return "settings.appearance.system"
        case .light:
            return "settings.appearance.light"
        case .dark:
            return "settings.appearance.dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

public enum AppLanguage: String, CaseIterable, Sendable, Identifiable {
    case korean = "ko"
    case english = "en"

    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .korean:
            return "settings.language.korean"
        case .english:
            return "settings.language.english"
        }
    }

    public var locale: Locale {
        Locale(identifier: rawValue)
    }
}

public enum InitialScreen: String, CaseIterable, Sendable, Identifiable {
    case board
    case calendar

    public var id: String { rawValue }

    public var labelKey: String {
        switch self {
        case .board:
            return "settings.initialScreen.board"
        case .calendar:
            return "settings.initialScreen.calendar"
        }
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    private static let appearanceKey = "settings.appAppearance"
    private static let languageKey = "settings.appLanguage"
    private static let reminderOptionsKey = "settings.reminder.options"
    private static let reminderHourKey = "settings.reminder.hour"
    private static let reminderMinuteKey = "settings.reminder.minute"
    private static let pushNotificationsEnabledKey = "settings.pushNotifications.enabled"
    private static let initialScreenKey = "settings.initialScreen"
    private static let hasRequestedInitialNotificationPermissionKey = "settings.pushNotifications.hasRequestedInitialPermission"
    private static let uploadDebounceInterval: TimeInterval = 0.8

    @Published public var selectedOptions: Set<ReminderOption> {
        didSet {
            let values = selectedOptions.map(\.rawValue).sorted(by: >)
            userDefaults.set(values, forKey: Self.reminderOptionsKey)
        }
    }
    @Published public var reminderTime: Date {
        didSet {
            let components = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
            userDefaults.set(components.hour ?? 9, forKey: Self.reminderHourKey)
            userDefaults.set(components.minute ?? 0, forKey: Self.reminderMinuteKey)
        }
    }
    @Published public var appAppearance: AppAppearance {
        didSet {
            userDefaults.set(appAppearance.rawValue, forKey: Self.appearanceKey)
        }
    }
    @Published public var appLanguage: AppLanguage {
        didSet {
            userDefaults.set(appLanguage.rawValue, forKey: Self.languageKey)
        }
    }
    @Published public var isPushNotificationsEnabled: Bool {
        didSet {
            userDefaults.set(isPushNotificationsEnabled, forKey: Self.pushNotificationsEnabledKey)
        }
    }
    @Published public var initialScreen: InitialScreen {
        didSet {
            userDefaults.set(initialScreen.rawValue, forKey: Self.initialScreenKey)
        }
    }
    @Published public private(set) var pushNotificationMessageKey: String?
    @Published public private(set) var pushPermissionActionButtonKey: String?
    @Published public private(set) var testReminderMessageKey: String?
    @Published public private(set) var isBackupConfigured: Bool
    @Published public private(set) var isBackupSignedIn = false
    @Published public private(set) var backupAccountIdentifier: String?
    @Published public private(set) var backupMessageKey: String?
    @Published public private(set) var backupErrorDebugText: String?
    @Published public private(set) var isBackupSignInInProgress = false
    @Published public private(set) var isBackupSyncInProgress = false
    @Published public private(set) var isAccountDeletionInProgress = false
    @Published public var isShowingRestorePromptAfterSignIn = false
    @Published public private(set) var latestBackupAt: Date?

    private let scheduler: any NotificationScheduler
    private let repository: any SubscriptionRepository
    private let userDefaults: UserDefaults
    private let serverClient: PayBoardServerClient?
    private let webAuthPresentationContext = WebAuthPresentationContext()
    private var kakaoWebAuthSession: ASWebAuthenticationSession?
    private var appleSignInNonce: String?
    private var lastUploadRequestedAt: Date?

    public init(
        scheduler: any NotificationScheduler = NoopNotificationScheduler(),
        repository: any SubscriptionRepository = InMemorySubscriptionRepository(seed: SampleData.subscriptions),
        userDefaults: UserDefaults = .standard
    ) {
        self.scheduler = scheduler
        self.repository = repository
        self.userDefaults = userDefaults
        let storedReminderOptionValues = userDefaults.array(forKey: Self.reminderOptionsKey) as? [Int] ?? []
        let restoredReminderOptions = Set(storedReminderOptionValues.compactMap(ReminderOption.init(rawValue:)))
        self.selectedOptions = restoredReminderOptions.isEmpty ? [.threeDays] : restoredReminderOptions
        let storedValue = userDefaults.string(forKey: Self.appearanceKey)
        self.appAppearance = AppAppearance(rawValue: storedValue ?? "") ?? .system
        let storedLanguage = userDefaults.string(forKey: Self.languageKey)
        self.appLanguage = AppLanguage(rawValue: storedLanguage ?? "") ?? .korean
        self.isPushNotificationsEnabled = userDefaults.object(forKey: Self.pushNotificationsEnabledKey) as? Bool ?? true
        let storedInitialScreen = userDefaults.string(forKey: Self.initialScreenKey)
        self.initialScreen = InitialScreen(rawValue: storedInitialScreen ?? "") ?? .board
        let storedHour = userDefaults.object(forKey: Self.reminderHourKey) as? Int ?? 9
        let storedMinute = userDefaults.object(forKey: Self.reminderMinuteKey) as? Int ?? 0
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = min(23, max(0, storedHour))
        components.minute = min(59, max(0, storedMinute))
        components.second = 0
        self.reminderTime = Calendar.current.date(from: components) ?? .now

        self.serverClient = Self.loadServerURL().map(PayBoardServerClient.init(baseURL:))
        self.isBackupConfigured = serverClient != nil

        Task {
            await handleInitialPushPermissionFlow()
            await refreshBackupAuthState()
        }
    }

    public func setPushNotificationsEnabled(_ isEnabled: Bool) async {
        if isEnabled {
            let granted = await scheduler.requestPermission()
            if granted {
                isPushNotificationsEnabled = true
                pushNotificationMessageKey = nil
                pushPermissionActionButtonKey = nil
            } else {
                await syncPushPermissionState()
            }
        } else {
            isPushNotificationsEnabled = false
            pushNotificationMessageKey = nil
            pushPermissionActionButtonKey = nil
        }
    }

    public func handlePushPermissionAction() async {
        let status = await scheduler.authorizationStatus()
        switch status {
        case .notDetermined:
            await setPushNotificationsEnabled(true)
        case .denied:
            #if os(iOS)
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            await MainActor.run {
                UIApplication.shared.open(url)
            }
            #endif
        case .authorized, .provisional, .ephemeral:
            isPushNotificationsEnabled = true
            pushNotificationMessageKey = nil
            pushPermissionActionButtonKey = nil
        }
    }

    public func refreshPushPermissionState() async {
        await syncPushPermissionState()
    }

    public func sendTestReminder() async {
        do {
            try await scheduler.scheduleTestNotification()
            testReminderMessageKey = "settings.reminder.test.success"
        } catch {
            testReminderMessageKey = "settings.reminder.test.failed"
        }
    }

    public var reminderDays: [Int] {
        selectedOptions.map(\.rawValue).sorted(by: >)
    }

    public var effectiveReminderOptions: Set<ReminderOption> {
        isPushNotificationsEnabled ? selectedOptions : []
    }

    public var reminderHour: Int {
        Calendar.current.component(.hour, from: reminderTime)
    }

    public var reminderMinute: Int {
        Calendar.current.component(.minute, from: reminderTime)
    }

    public var preferredColorScheme: ColorScheme? {
        appAppearance.colorScheme
    }

    public var preferredLocale: Locale {
        appLanguage.locale
    }

    public var latestBackupAtText: String? {
        guard let latestBackupAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = preferredLocale
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: latestBackupAt)
    }

    public var deleteAccountConfirmationMessage: String {
        if let account = backupAccountIdentifier {
            return String(
                format: NSLocalizedString("settings.backup.deleteAccount.confirm.message.account", comment: ""),
                account
            )
        }
        return NSLocalizedString("settings.backup.deleteAccount.confirm.message", comment: "")
    }

    public var backupConfigurationDebugText: String {
        let processEnvironment = ProcessInfo.processInfo.environment
        let envServerURL = processEnvironment["PAYBOARD_SERVER_URL"] ?? processEnvironment["INFOPLIST_KEY_PAYBOARD_SERVER_URL"]
        let bundleServerURL = Self.infoDictionaryStringValue(forPrimaryKey: "PAYBOARD_SERVER_URL", fallbackKey: "INFOPLIST_KEY_PAYBOARD_SERVER_URL")
        let normalizedServerURL = Self.normalizedSecretValue(envServerURL ?? bundleServerURL) ?? "<nil>"

        return [
            "ENV PAYBOARD_SERVER_URL: \(envServerURL ?? "<nil>")",
            "BUNDLE PAYBOARD_SERVER_URL: \(bundleServerURL ?? "<nil>")",
            "BACKUP AUTH REDIRECT URL: \(Self.loadBackupAuthRedirectURL()?.absoluteString ?? "<nil>")",
            "NORMALIZED SERVER URL: \(normalizedServerURL)",
            "isBackupConfigured: \(isBackupConfigured)"
        ].joined(separator: "\n")
    }

    public func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        backupErrorDebugText = nil
        guard isBackupConfigured else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }

        let nonce = Self.randomNonceString()
        appleSignInNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    public func handleAppleSignInCompletion(_ result: Result<ASAuthorization, any Error>) async {
        backupErrorDebugText = nil
        guard let serverClient else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }

        switch result {
        case let .success(authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = credential.identityToken,
                  let idToken = String(data: identityToken, encoding: .utf8) else {
                backupMessageKey = "settings.backup.signIn.invalidCredential"
                return
            }

            guard let rawNonce = appleSignInNonce else {
                backupMessageKey = "settings.backup.signIn.missingNonce"
                return
            }

            do {
                _ = try await serverClient.signInWithApple(idToken: idToken, nonce: rawNonce)
                appleSignInNonce = nil
                await refreshBackupAuthState()
                if let email = credential.email, !email.isEmpty {
                    backupAccountIdentifier = email
                }
                backupMessageKey = "settings.backup.signIn.success"
                await bootstrapBackupAfterSignIn()
            } catch {
                backupMessageKey = "settings.backup.signIn.failed"
                backupErrorDebugText = Self.describeBackupSignInError(error, stage: "server")
            }
        case let .failure(error):
            backupMessageKey = "settings.backup.signIn.failed"
            backupErrorDebugText = Self.describeBackupSignInError(error, stage: "apple")
        }
    }

    public func signInWithKakao() async {
        guard !isBackupSignInInProgress else { return }

        backupErrorDebugText = nil
        guard let serverClient else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }
        guard let redirectTo = Self.loadBackupAuthRedirectURL() else {
            backupMessageKey = "settings.backup.signIn.redirectNotConfigured"
            backupErrorDebugText = "PAYBOARD_AUTH_URL_SCHEME is missing"
            return
        }

        isBackupSignInInProgress = true
        defer { isBackupSignInInProgress = false }

        do {
            let codeVerifier = Self.randomCodeVerifier()
            guard let startURL = serverClient.kakaoStartURL(
                redirectTo: redirectTo,
                codeChallenge: Self.codeChallenge(for: codeVerifier)
            ) else {
                throw URLError(.badURL)
            }
            let callbackURL = try await authenticateInBrowser(url: startURL, callbackScheme: redirectTo.scheme)
            let queryItems = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
            guard let code = queryItems.first(where: { $0.name == "code" })?.value else {
                let reason = queryItems.first(where: { $0.name == "error" })?.value ?? "missing_code"
                throw ServerError(statusCode: 401, message: reason)
            }
            _ = try await serverClient.exchangeKakaoCode(code, codeVerifier: codeVerifier)
            await refreshBackupAuthState()
            backupMessageKey = "settings.backup.signIn.success"
            backupErrorDebugText = nil
            await bootstrapBackupAfterSignIn()
        } catch {
            if Self.isOAuthCancellationError(error) {
                backupMessageKey = "settings.backup.signIn.cancelled"
                backupErrorDebugText = nil
                return
            }
            backupMessageKey = "settings.backup.signIn.failed.kakao"
            backupErrorDebugText = Self.describeBackupSignInError(error, stage: "kakao")
        }
    }

    public func signOutBackup() async {
        guard let serverClient else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }

        await serverClient.signOut()
        isBackupSignedIn = false
        backupAccountIdentifier = nil
        latestBackupAt = nil
        backupMessageKey = "settings.backup.signOut.success"
    }

    public func deleteAccount() async {
        guard !isBackupSyncInProgress, !isAccountDeletionInProgress else { return }
        guard let serverClient else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }

        isAccountDeletionInProgress = true
        defer { isAccountDeletionInProgress = false }

        do {
            try await serverClient.deleteAccount()
            clearBackupStateAfterAccountDeletion()
            backupMessageKey = "settings.backup.deleteAccount.success"
            backupErrorDebugText = nil
        } catch {
            backupMessageKey = "settings.backup.deleteAccount.failed"
            backupErrorDebugText = Self.describeBackupSyncError(error, operation: "delete_account")
        }
    }

    public func uploadBackup() async {
        await uploadBackup(showResultMessage: true)
    }

    public func autoBackupAfterSubscriptionUpsert() async {
        await uploadBackup(showResultMessage: false)
    }

    private func uploadBackup(showResultMessage: Bool) async {
        let now = Date()
        if let lastUploadRequestedAt,
           now.timeIntervalSince(lastUploadRequestedAt) < Self.uploadDebounceInterval {
            return
        }
        lastUploadRequestedAt = now

        guard !isBackupSyncInProgress else { return }
        guard let serverClient else {
            if showResultMessage {
                backupMessageKey = "settings.backup.notConfigured"
            }
            return
        }
        guard isBackupSignedIn else { return }

        isBackupSyncInProgress = true
        defer { isBackupSyncInProgress = false }

        do {
            latestBackupAt = try await uploadCurrentDataAsBackup(client: serverClient)
            if showResultMessage {
                backupMessageKey = "settings.backup.upload.success"
            }
            backupErrorDebugText = nil
        } catch {
            if showResultMessage {
                backupMessageKey = "settings.backup.upload.failed"
            }
            backupErrorDebugText = Self.describeBackupSyncError(error, operation: "upload")
        }
    }

    public func restoreLatestBackup() async {
        guard !isBackupSyncInProgress else { return }
        guard let serverClient else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }

        isBackupSyncInProgress = true
        defer { isBackupSyncInProgress = false }

        do {
            let existingSubscriptions = try await fetchAllLocalSubscriptions()
            guard let latestBackup = try await serverClient.backupMetadata() else {
                backupMessageKey = "settings.backup.restore.empty"
                backupErrorDebugText = nil
                return
            }

            let backupData = try await serverClient.backupData(as: BackupDataResponse.self)
            if latestBackup.item_count > 0 && backupData.items.isEmpty {
                throw DomainError.notFound
            }

            let restoredSubscriptions = try buildSubscriptions(
                from: backupData.items,
                paymentHistories: backupData.payment_histories
            )

            try await replaceAllSubscriptions(with: restoredSubscriptions)
            let updated = try await repository.fetchAll()
            let updatedIDs = Set(updated.map(\.id))
            for subscription in existingSubscriptions where !updatedIDs.contains(subscription.id) {
                await scheduler.cancel(for: subscription.id)
            }
            try await scheduler.rescheduleAll(
                subscriptions: updated,
                reminderDays: effectiveReminderOptions.map(\.rawValue).sorted(by: >),
                reminderHour: reminderHour,
                reminderMinute: reminderMinute
            )
            WidgetSnapshotStore.save(subscriptions: updated)
            backupMessageKey = "settings.backup.restore.success"
            backupErrorDebugText = nil
            latestBackupAt = latestBackup.updated_at
        } catch {
            backupMessageKey = "settings.backup.restore.failed"
            backupErrorDebugText = Self.describeBackupSyncError(error, operation: "restore")
        }
    }

    public func refreshBackupAuthState() async {
        guard let serverClient, let session = await serverClient.currentSession else {
            isBackupSignedIn = false
            backupAccountIdentifier = nil
            latestBackupAt = nil
            return
        }

        isBackupSignedIn = true
        backupAccountIdentifier = session.user.email ?? session.user.id
        do {
            latestBackupAt = try await serverClient.backupMetadata()?.updated_at
        } catch let error as ServerError where error.isUnauthorized {
            isBackupSignedIn = false
            backupAccountIdentifier = nil
            latestBackupAt = nil
        } catch {
            // 오프라인 등 일시적 실패로 로그인 상태까지 잃지 않도록 세션은 유지함
            latestBackupAt = nil
        }
    }

    private struct BackupUpload: Encodable, Sendable {
        let backup_version: Int
        let items: [BackupSubscriptionItemRow]
        let payment_histories: [BackupPaymentHistoryRow]
    }

    private struct BackupDataResponse: Decodable, Sendable {
        let items: [BackupSubscriptionItemRow]
        let payment_histories: [BackupPaymentHistoryRow]
    }

    private struct BackupSubscriptionItemRow: Codable, Sendable {
        let id: UUID
        let name: String
        let category: String
        let amount: Decimal
        let is_amount_undecided: Bool
        let currency_code: String
        let billing_cycle_kind: String
        let billing_cycle_days: Int
        let next_billing_date: Date
        let billing_anchor_day: Int?
        let last_payment_date: Date?
        let icon_key: String
        let icon_color_key: String
        let custom_category_name: String?
        let notifications_enabled: Bool
        let is_auto_pay_enabled: Bool
        let is_pinned: Bool
        let is_active: Bool
        let memo: String?
        let sort_order: Int
        let created_at: Date
        let updated_at: Date
    }

    private struct BackupPaymentHistoryRow: Codable, Sendable {
        let subscription_id: UUID
        let paid_at: Date
        let scheduled_date: Date
        let amount_snapshot: Decimal
        let currency_code: String
        let is_auto_pay: Bool
        let status: String
        let created_at: Date
        let updated_at: Date
    }

    private static func loadServerURL() -> URL? {
        let processEnvironment = ProcessInfo.processInfo.environment
        let urlValue = normalizedSecretValue(
            processEnvironment["PAYBOARD_SERVER_URL"]
                ?? processEnvironment["INFOPLIST_KEY_PAYBOARD_SERVER_URL"]
                ?? infoDictionaryStringValue(forPrimaryKey: "PAYBOARD_SERVER_URL", fallbackKey: "INFOPLIST_KEY_PAYBOARD_SERVER_URL")
        )
        guard let urlValue, let url = URL(string: urlValue) else {
            return nil
        }
        return url
    }

    private static func loadBackupAuthRedirectURL() -> URL? {
        let processEnvironment = ProcessInfo.processInfo.environment
        let scheme = normalizedSecretValue(
            processEnvironment["PAYBOARD_AUTH_URL_SCHEME"]
                ?? processEnvironment["INFOPLIST_KEY_PAYBOARD_AUTH_URL_SCHEME"]
                ?? infoDictionaryStringValue(forPrimaryKey: "PAYBOARD_AUTH_URL_SCHEME", fallbackKey: "INFOPLIST_KEY_PAYBOARD_AUTH_URL_SCHEME")
        )

        guard let scheme else {
            return nil
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = "auth"
        components.path = "/callback"
        return components.url
    }

    private static func infoDictionaryStringValue(forPrimaryKey primaryKey: String, fallbackKey: String) -> String? {
        if let value = Bundle.main.object(forInfoDictionaryKey: primaryKey) as? String {
            return value
        }
        return Bundle.main.object(forInfoDictionaryKey: fallbackKey) as? String
    }

    private static func normalizedSecretValue(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("$(") else {
            return nil
        }
        return trimmed
    }

    private static func describeBackupSignInError(_ error: any Error, stage: String) -> String {
        let nsError = error as NSError
        return "stage=\(stage), domain=\(nsError.domain), code=\(nsError.code), desc=\(nsError.localizedDescription)"
    }

    private static func describeBackupSyncError(_ error: any Error, operation: String) -> String {
        let nsError = error as NSError
        return "operation=\(operation), domain=\(nsError.domain), code=\(nsError.code), desc=\(nsError.localizedDescription)"
    }

    private static func isOAuthCancellationError(_ error: any Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == ASWebAuthenticationSessionError.errorDomain
            && nsError.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
    }

    private func clearBackupStateAfterAccountDeletion() {
        isBackupSignedIn = false
        backupAccountIdentifier = nil
        latestBackupAt = nil
        isShowingRestorePromptAfterSignIn = false
        lastUploadRequestedAt = nil
    }

    private func bootstrapBackupAfterSignIn() async {
        guard let serverClient else { return }

        do {
            if let metadata = try await serverClient.backupMetadata() {
                backupMessageKey = "settings.backup.signIn.restorePrompt"
                isShowingRestorePromptAfterSignIn = true
                latestBackupAt = metadata.updated_at
            } else {
                latestBackupAt = try await uploadCurrentDataAsBackup(client: serverClient)
                backupMessageKey = "settings.backup.signIn.autoBackupDone"
            }
        } catch {
            backupErrorDebugText = Self.describeBackupSyncError(error, operation: "post_sign_in_bootstrap")
        }
    }

    private func uploadCurrentDataAsBackup(client: PayBoardServerClient) async throws -> Date {
        let subscriptions = try await fetchAllLocalSubscriptions()
        let upload = BackupUpload(
            backup_version: 2,
            items: subscriptions.enumerated().map { index, subscription in
                makeBackupSubscriptionItemRow(from: subscription, sortOrder: index)
            },
            payment_histories: subscriptions.flatMap(makePaymentHistoryRows(from:))
        )
        return try await client.putBackup(upload).updated_at
    }

    private func authenticateInBrowser(url: URL, callbackScheme: String?) async throws -> URL {
        defer { kakaoWebAuthSession = nil }
        return try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackScheme) { callbackURL, error in
                if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: error ?? URLError(.userCancelledAuthentication))
                }
            }
            session.presentationContextProvider = webAuthPresentationContext
            kakaoWebAuthSession = session
            if !session.start() {
                continuation.resume(throwing: URLError(.cannotOpenFile))
            }
        }
    }

    private func fetchAllLocalSubscriptions() async throws -> [Subscription] {
        let active = try await repository.fetchAll()
        let archived = try await repository.fetchArchived()
        return active + archived
    }

    private func buildSubscriptions(
        from remoteSubscriptions: [BackupSubscriptionItemRow],
        paymentHistories: [BackupPaymentHistoryRow]
    ) throws -> [Subscription] {
        let paymentHistoryMap = Dictionary(grouping: paymentHistories, by: \.subscription_id)
        return try remoteSubscriptions
            .sorted { lhs, rhs in
                if lhs.sort_order != rhs.sort_order {
                    return lhs.sort_order < rhs.sort_order
                }
                return lhs.created_at < rhs.created_at
            }
            .map { row in
                let paidDates = (paymentHistoryMap[row.id] ?? [])
                    .map(\.paid_at)
                    .sorted(by: <)
                return try makeSubscription(
                    from: row,
                    paymentHistoryDates: paidDates
                )
            }
    }

    private func makeBackupSubscriptionItemRow(
        from subscription: Subscription,
        sortOrder: Int
    ) -> BackupSubscriptionItemRow {
        let billingCycle = flattenBillingCycle(subscription.billingCycle)
        return BackupSubscriptionItemRow(
            id: subscription.id,
            name: subscription.name,
            category: subscription.category.rawValue,
            amount: subscription.amount,
            is_amount_undecided: subscription.isAmountUndecided,
            currency_code: subscription.currencyCode,
            billing_cycle_kind: billingCycle.kind,
            billing_cycle_days: billingCycle.days,
            next_billing_date: subscription.nextBillingDate,
            billing_anchor_day: subscription.billingAnchorDay,
            last_payment_date: subscription.lastPaymentDate,
            icon_key: subscription.iconKey,
            icon_color_key: subscription.iconColorKey,
            custom_category_name: subscription.customCategoryName,
            notifications_enabled: subscription.notificationsEnabled,
            is_auto_pay_enabled: subscription.isAutoPayEnabled,
            is_pinned: subscription.isPinned,
            is_active: subscription.isActive,
            memo: subscription.memo,
            sort_order: sortOrder,
            created_at: subscription.createdAt,
            updated_at: subscription.updatedAt
        )
    }

    private func makePaymentHistoryRows(
        from subscription: Subscription
    ) -> [BackupPaymentHistoryRow] {
        let paidDates = Array(
            Set(
                (subscription.paymentHistoryDates + [subscription.lastPaymentDate].compactMap { $0 })
                    .map { Calendar.current.startOfDay(for: $0) }
            )
        ).sorted(by: <)

        return paidDates.map { paidAt in
            BackupPaymentHistoryRow(
                subscription_id: subscription.id,
                paid_at: paidAt,
                scheduled_date: paidAt,
                amount_snapshot: subscription.amount,
                currency_code: subscription.currencyCode,
                is_auto_pay: subscription.isAutoPayEnabled,
                status: "paid",
                created_at: subscription.createdAt,
                updated_at: subscription.updatedAt
            )
        }
    }

    private func makeSubscription(
        from row: BackupSubscriptionItemRow,
        paymentHistoryDates: [Date]
    ) throws -> Subscription {
        guard let category = SubscriptionCategory(rawValue: row.category) else {
            throw DomainError.validation("Unsupported category: \(row.category)")
        }

        return Subscription(
            id: row.id,
            name: row.name,
            category: category,
            amount: row.amount,
            isAmountUndecided: row.is_amount_undecided,
            currencyCode: row.currency_code,
            billingCycle: try expandBillingCycle(
                kind: row.billing_cycle_kind,
                days: row.billing_cycle_days
            ),
            nextBillingDate: row.next_billing_date,
            billingAnchorDay: row.billing_anchor_day,
            lastPaymentDate: paymentHistoryDates.max() ?? row.last_payment_date,
            paymentHistoryDates: paymentHistoryDates,
            iconKey: row.icon_key,
            iconColorKey: row.icon_color_key,
            customCategoryName: row.custom_category_name,
            notificationsEnabled: row.notifications_enabled,
            isAutoPayEnabled: row.is_auto_pay_enabled,
            isPinned: row.is_pinned,
            isActive: row.is_active,
            memo: row.memo,
            createdAt: row.created_at,
            updatedAt: row.updated_at
        )
    }

    private func flattenBillingCycle(_ cycle: BillingCycle) -> (kind: String, days: Int) {
        switch cycle {
        case .monthly:
            return ("monthly", 30)
        case .yearly:
            return ("yearly", 365)
        case let .customDays(days):
            return ("custom_days", max(1, days))
        }
    }

    private func expandBillingCycle(
        kind: String,
        days: Int
    ) throws -> BillingCycle {
        switch kind {
        case "monthly":
            return .monthly
        case "yearly":
            return .yearly
        case "custom_days":
            return .customDays(max(1, days))
        default:
            throw DomainError.validation("Unsupported billing cycle: \(kind)")
        }
    }

    private func handleInitialPushPermissionFlow() async {
        let hasRequestedInitialPermission = userDefaults.bool(forKey: Self.hasRequestedInitialNotificationPermissionKey)
        if !hasRequestedInitialPermission {
            userDefaults.set(true, forKey: Self.hasRequestedInitialNotificationPermissionKey)
            let granted = await scheduler.requestPermission()
            if granted {
                isPushNotificationsEnabled = true
                pushNotificationMessageKey = nil
                pushPermissionActionButtonKey = nil
            } else {
                await syncPushPermissionState()
            }
            return
        }

        await syncPushPermissionState()
    }

    private func syncPushPermissionState() async {
        let status = await scheduler.authorizationStatus()
        switch status {
        case .notDetermined:
            isPushNotificationsEnabled = false
            pushNotificationMessageKey = nil
            pushPermissionActionButtonKey = "settings.push.requestPermission"
        case .denied:
            isPushNotificationsEnabled = false
            pushNotificationMessageKey = "settings.push.permissionDenied"
            pushPermissionActionButtonKey = "settings.push.openSettings"
        case .authorized, .provisional, .ephemeral:
            pushNotificationMessageKey = nil
            pushPermissionActionButtonKey = nil
        }
    }

    public func confirmRestoreAfterSignIn() async {
        isShowingRestorePromptAfterSignIn = false
        await restoreLatestBackup()
    }

    public func skipRestoreAfterSignIn() {
        isShowingRestorePromptAfterSignIn = false
        backupMessageKey = "settings.backup.signIn.restoreSkipped"
    }

    private func replaceAllSubscriptions(with incoming: [Subscription]) async throws {
        let current = try await fetchAllLocalSubscriptions()
        let currentIDs = Set(current.map(\.id))
        let incomingIDs = Set(incoming.map(\.id))

        for subscription in incoming {
            if currentIDs.contains(subscription.id) {
                try await repository.update(subscription)
            } else {
                try await repository.create(subscription)
            }
        }

        for subscription in current where !incomingIDs.contains(subscription.id) {
            try await repository.delete(id: subscription.id)
        }
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    // 서버가 code_challenge 로 S256(base64url) 만 받으므로 그 규격에 맞춤
    private static func randomCodeVerifier() -> String {
        base64URLEncoded(Data(SymmetricKey(size: .bits256).withUnsafeBytes { Array($0) }))
    }

    private static func codeChallenge(for verifier: String) -> String {
        base64URLEncoded(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    private static func base64URLEncoded(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }
}

@MainActor
private final class WebAuthPresentationContext: NSObject, ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if os(iOS)
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        return windows.first(where: \.isKeyWindow) ?? windows.first ?? ASPresentationAnchor()
        #else
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #endif
    }
}
