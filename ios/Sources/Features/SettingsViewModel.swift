import Foundation
import SwiftUI
import Domain
import Data
import AuthenticationServices
import CryptoKit
import Security
import Supabase
#if os(iOS)
import UIKit
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
    private static let boardSearchVisibleKey = "settings.board.searchVisible"
    private static let initialScreenKey = "settings.initialScreen"
    private static let hasRequestedInitialNotificationPermissionKey = "settings.pushNotifications.hasRequestedInitialPermission"
    private static let latestBackupsTable = "subscription_latest_backups"
    private static let backupItemsTable = "subscription_items"
    private static let paymentHistoriesTable = "subscription_payment_histories"
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
    @Published public var isBoardSearchVisible: Bool {
        didSet {
            userDefaults.set(isBoardSearchVisible, forKey: Self.boardSearchVisibleKey)
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
    @Published public private(set) var isBackupSyncInProgress = false
    @Published public private(set) var isAccountDeletionInProgress = false
    @Published public var isShowingRestorePromptAfterSignIn = false
    @Published public private(set) var latestBackupAt: Date?

    private let scheduler: any NotificationScheduler
    private let repository: any SubscriptionRepository
    private let userDefaults: UserDefaults
    private let supabaseClient: SupabaseClient?
    private let accountDeletionServerURL: URL?
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
        self.isBoardSearchVisible = userDefaults.object(forKey: Self.boardSearchVisibleKey) as? Bool ?? true
        let storedInitialScreen = userDefaults.string(forKey: Self.initialScreenKey)
        self.initialScreen = InitialScreen(rawValue: storedInitialScreen ?? "") ?? .board
        let storedHour = userDefaults.object(forKey: Self.reminderHourKey) as? Int ?? 9
        let storedMinute = userDefaults.object(forKey: Self.reminderMinuteKey) as? Int ?? 0
        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = min(23, max(0, storedHour))
        components.minute = min(59, max(0, storedMinute))
        components.second = 0
        self.reminderTime = Calendar.current.date(from: components) ?? .now

        if let config = Self.loadSupabaseConfiguration() {
            self.supabaseClient = SupabaseClient(supabaseURL: config.url, supabaseKey: config.anonKey)
            self.isBackupConfigured = true
        } else {
            self.supabaseClient = nil
            self.isBackupConfigured = false
        }
        self.accountDeletionServerURL = Self.loadAccountDeletionServerURL()

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
        let envURL = processEnvironment["SUPABASE_URL"] ?? processEnvironment["INFOPLIST_KEY_SUPABASE_URL"]
        let envKey = processEnvironment["SUPABASE_ANON_KEY"] ?? processEnvironment["INFOPLIST_KEY_SUPABASE_ANON_KEY"]
        let envServerURL = processEnvironment["PAYBOARD_SERVER_URL"] ?? processEnvironment["INFOPLIST_KEY_PAYBOARD_SERVER_URL"]
        let bundleURL = Self.infoDictionaryStringValue(forPrimaryKey: "SUPABASE_URL", fallbackKey: "INFOPLIST_KEY_SUPABASE_URL")
        let bundleKey = Self.infoDictionaryStringValue(forPrimaryKey: "SUPABASE_ANON_KEY", fallbackKey: "INFOPLIST_KEY_SUPABASE_ANON_KEY")
        let bundleServerURL = Self.infoDictionaryStringValue(forPrimaryKey: "PAYBOARD_SERVER_URL", fallbackKey: "INFOPLIST_KEY_PAYBOARD_SERVER_URL")
        let normalizedURL = Self.normalizedSecretValue(envURL ?? bundleURL) ?? "<nil>"
        let normalizedKey = Self.normalizedSecretValue(envKey ?? bundleKey).map(Self.maskSecretValue) ?? "<nil>"
        let normalizedServerURL = Self.normalizedSecretValue(envServerURL ?? bundleServerURL) ?? "<nil>"

        return [
            "ENV SUPABASE_URL: \(envURL ?? "<nil>")",
            "BUNDLE SUPABASE_URL: \(bundleURL ?? "<nil>")",
            "ENV SUPABASE_ANON_KEY: \(envKey.map(Self.maskSecretValue) ?? "<nil>")",
            "BUNDLE SUPABASE_ANON_KEY: \(bundleKey.map(Self.maskSecretValue) ?? "<nil>")",
            "ENV PAYBOARD_SERVER_URL: \(envServerURL ?? "<nil>")",
            "BUNDLE PAYBOARD_SERVER_URL: \(bundleServerURL ?? "<nil>")",
            "NORMALIZED URL: \(normalizedURL)",
            "NORMALIZED KEY: \(normalizedKey)",
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
        guard let supabaseClient else {
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
                _ = try await supabaseClient.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: rawNonce
                    )
                )
                appleSignInNonce = nil
                await refreshBackupAuthState()
                if let email = credential.email, !email.isEmpty {
                    backupAccountIdentifier = email
                }
                backupMessageKey = "settings.backup.signIn.success"
                await bootstrapBackupAfterSignIn()
            } catch {
                backupMessageKey = "settings.backup.signIn.failed"
                backupErrorDebugText = Self.describeBackupSignInError(error, stage: "supabase")
            }
        case let .failure(error):
            backupMessageKey = "settings.backup.signIn.failed"
            backupErrorDebugText = Self.describeBackupSignInError(error, stage: "apple")
        }
    }

    public func signOutBackup() async {
        guard let supabaseClient else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }

        do {
            try await supabaseClient.auth.signOut()
            isBackupSignedIn = false
            backupAccountIdentifier = nil
            latestBackupAt = nil
            backupMessageKey = "settings.backup.signOut.success"
        } catch {
            backupMessageKey = "settings.backup.signOut.failed"
        }
    }

    public func deleteAccount() async {
        guard !isBackupSyncInProgress, !isAccountDeletionInProgress else { return }
        guard let supabaseClient else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }
        guard let accountDeletionServerURL else {
            backupMessageKey = "settings.backup.deleteAccount.serverNotConfigured"
            backupErrorDebugText = "PAYBOARD_SERVER_URL is missing"
            return
        }

        isAccountDeletionInProgress = true
        defer { isAccountDeletionInProgress = false }

        do {
            let session = try await supabaseClient.auth.session
            try await deleteAccountFromServer(
                accessToken: session.accessToken,
                serverURL: accountDeletionServerURL
            )
            try? await supabaseClient.auth.signOut()
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
        guard let supabaseClient else {
            if showResultMessage {
                backupMessageKey = "settings.backup.notConfigured"
            }
            return
        }
        guard isBackupSignedIn else { return }

        isBackupSyncInProgress = true
        defer { isBackupSyncInProgress = false }

        do {
            let session = try await supabaseClient.auth.session
            let subscriptions = try await fetchAllLocalSubscriptions()
            let timestamp = Date()
            try await replaceRemoteBackup(
                with: subscriptions,
                for: session.user.id,
                client: supabaseClient,
                updatedAt: timestamp
            )
            latestBackupAt = timestamp
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
        guard let supabaseClient else {
            backupMessageKey = "settings.backup.notConfigured"
            return
        }

        isBackupSyncInProgress = true
        defer { isBackupSyncInProgress = false }

        do {
            let session = try await supabaseClient.auth.session
            let metadata = try await fetchLatestBackupMetadata(for: session.user.id, client: supabaseClient)
            guard let latestBackup = metadata else {
                backupMessageKey = "settings.backup.restore.empty"
                backupErrorDebugText = nil
                return
            }

            let remoteSubscriptions = try await fetchRemoteSubscriptions(for: session.user.id, client: supabaseClient)
            if latestBackup.item_count > 0 && remoteSubscriptions.isEmpty {
                throw DomainError.notFound
            }

            let remotePaymentHistories = try await fetchRemotePaymentHistories(for: session.user.id, client: supabaseClient)
            let restoredSubscriptions = try buildSubscriptions(
                from: remoteSubscriptions,
                paymentHistories: remotePaymentHistories
            )

            try await replaceAllSubscriptions(with: restoredSubscriptions)
            let updated = try await repository.fetchAll()
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
        guard let supabaseClient else {
            isBackupSignedIn = false
            backupAccountIdentifier = nil
            return
        }

        do {
            let session = try await supabaseClient.auth.session
            isBackupSignedIn = true
            backupAccountIdentifier = session.user.email ?? session.user.id.uuidString
            latestBackupAt = try await fetchLatestBackupMetadata(for: session.user.id, client: supabaseClient)?.updated_at
        } catch {
            isBackupSignedIn = false
            backupAccountIdentifier = nil
            latestBackupAt = nil
        }
    }

    private struct SupabaseConfiguration {
        let url: URL
        let anonKey: String
    }

    private struct DeleteAccountResponse: Decodable {
        let deleted_user_id: String
        let deleted_at: Date
    }

    private struct BackupMetadataUpsertRow: Encodable {
        let user_id: UUID
        let backup_version: Int
        let item_count: Int
        let device_id: String?
        let app_version: String?
        let updated_at: Date
    }

    private struct BackupMetadataRow: Decodable {
        let user_id: UUID
        let item_count: Int
        let created_at: Date
        let updated_at: Date
    }

    private struct BackupSubscriptionItemRow: Codable {
        let id: UUID
        let user_id: UUID
        let name: String
        let category: String
        let amount: Decimal
        let is_amount_undecided: Bool
        let currency_code: String
        let billing_cycle_kind: String
        let billing_cycle_days: Int
        let next_billing_date: Date
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

    private struct BackupPaymentHistoryRow: Codable {
        let user_id: UUID
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

    private static func loadSupabaseConfiguration() -> SupabaseConfiguration? {
        let processEnvironment = ProcessInfo.processInfo.environment
        let urlValue = normalizedSecretValue(
            processEnvironment["SUPABASE_URL"]
                ?? processEnvironment["INFOPLIST_KEY_SUPABASE_URL"]
                ?? infoDictionaryStringValue(forPrimaryKey: "SUPABASE_URL", fallbackKey: "INFOPLIST_KEY_SUPABASE_URL")
        )
        let keyValue = normalizedSecretValue(
            processEnvironment["SUPABASE_ANON_KEY"]
                ?? processEnvironment["INFOPLIST_KEY_SUPABASE_ANON_KEY"]
                ?? infoDictionaryStringValue(forPrimaryKey: "SUPABASE_ANON_KEY", fallbackKey: "INFOPLIST_KEY_SUPABASE_ANON_KEY")
        )
        guard let urlValue, let keyValue, let url = URL(string: urlValue) else {
            return nil
        }
        return SupabaseConfiguration(url: url, anonKey: keyValue)
    }

    private static func loadAccountDeletionServerURL() -> URL? {
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

    private static func maskSecretValue(_ rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "<empty>" }
        if trimmed.count <= 8 {
            return String(repeating: "*", count: trimmed.count)
        }
        let prefix = trimmed.prefix(6)
        let suffix = trimmed.suffix(4)
        return "\(prefix)...\(suffix)"
    }

    private static func describeBackupSignInError(_ error: any Error, stage: String) -> String {
        let nsError = error as NSError
        return "stage=\(stage), domain=\(nsError.domain), code=\(nsError.code), desc=\(nsError.localizedDescription)"
    }

    private static func describeBackupSyncError(_ error: any Error, operation: String) -> String {
        let nsError = error as NSError
        return "operation=\(operation), domain=\(nsError.domain), code=\(nsError.code), desc=\(nsError.localizedDescription)"
    }

    private func deleteAccountFromServer(
        accessToken: String,
        serverURL: URL
    ) async throws {
        let endpoint = serverURL
            .appendingPathComponent("v1", isDirectory: true)
            .appendingPathComponent("account", isDirectory: true)
            .appendingPathComponent("delete", isDirectory: false)

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(["reason": "user_requested"])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = Self.extractServerErrorMessage(from: data) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(
                domain: "SettingsViewModel.DeleteAccount",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        _ = try decoder.decode(DeleteAccountResponse.self, from: data)
    }

    private static func extractServerErrorMessage(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }
        if let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorMessage = payload["error"] as? String,
           !errorMessage.isEmpty {
            return errorMessage
        }
        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
    }

    private func clearBackupStateAfterAccountDeletion() {
        isBackupSignedIn = false
        backupAccountIdentifier = nil
        latestBackupAt = nil
        isShowingRestorePromptAfterSignIn = false
        lastUploadRequestedAt = nil
    }

    private func bootstrapBackupAfterSignIn() async {
        guard let supabaseClient else { return }

        do {
            let session = try await supabaseClient.auth.session
            if let metadata = try await fetchLatestBackupMetadata(for: session.user.id, client: supabaseClient) {
                backupMessageKey = "settings.backup.signIn.restorePrompt"
                isShowingRestorePromptAfterSignIn = true
                latestBackupAt = metadata.updated_at
            } else {
                try await uploadCurrentDataAsBackup(for: session.user.id, client: supabaseClient)
                backupMessageKey = "settings.backup.signIn.autoBackupDone"
                latestBackupAt = .now
            }
        } catch {
            backupErrorDebugText = Self.describeBackupSyncError(error, operation: "post_sign_in_bootstrap")
        }
    }

    private func fetchLatestBackupMetadata(
        for userID: UUID,
        client: SupabaseClient
    ) async throws -> BackupMetadataRow? {
        let rows: [BackupMetadataRow] = try await client
            .from(Self.latestBackupsTable)
            .select("user_id,item_count,created_at,updated_at")
            .eq("user_id", value: userID)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    private func uploadCurrentDataAsBackup(
        for userID: UUID,
        client: SupabaseClient
    ) async throws {
        let subscriptions = try await fetchAllLocalSubscriptions()
        try await replaceRemoteBackup(
            with: subscriptions,
            for: userID,
            client: client,
            updatedAt: .now
        )
    }

    private func fetchAllLocalSubscriptions() async throws -> [Subscription] {
        let active = try await repository.fetchAll()
        let archived = try await repository.fetchArchived()
        return active + archived
    }

    private func replaceRemoteBackup(
        with subscriptions: [Subscription],
        for userID: UUID,
        client: SupabaseClient,
        updatedAt: Date
    ) async throws {
        try await deleteRemoteBackupTables(for: userID, client: client)

        let itemRows = subscriptions.enumerated().map { index, subscription in
            makeBackupSubscriptionItemRow(
                from: subscription,
                userID: userID,
                sortOrder: index
            )
        }

        if !itemRows.isEmpty {
            try await client
                .from(Self.backupItemsTable)
                .insert(itemRows)
                .execute()
        }

        let paymentRows = subscriptions.flatMap { subscription in
            makePaymentHistoryRows(from: subscription, userID: userID)
        }

        if !paymentRows.isEmpty {
            try await client
                .from(Self.paymentHistoriesTable)
                .insert(paymentRows)
                .execute()
        }

        let metadataRow = BackupMetadataUpsertRow(
            user_id: userID,
            backup_version: 2,
            item_count: subscriptions.count,
            device_id: nil,
            app_version: nil,
            updated_at: updatedAt
        )
        try await client
            .from(Self.latestBackupsTable)
            .upsert(metadataRow, onConflict: "user_id")
            .execute()
    }

    private func deleteRemoteBackupTables(
        for userID: UUID,
        client: SupabaseClient
    ) async throws {
        try await client
            .from(Self.paymentHistoriesTable)
            .delete()
            .eq("user_id", value: userID)
            .execute()

        try await client
            .from(Self.backupItemsTable)
            .delete()
            .eq("user_id", value: userID)
            .execute()
    }

    private func fetchRemoteSubscriptions(
        for userID: UUID,
        client: SupabaseClient
    ) async throws -> [BackupSubscriptionItemRow] {
        try await client
            .from(Self.backupItemsTable)
            .select("""
                id,
                user_id,
                name,
                category,
                amount,
                is_amount_undecided,
                currency_code,
                billing_cycle_kind,
                billing_cycle_days,
                next_billing_date,
                last_payment_date,
                icon_key,
                icon_color_key,
                custom_category_name,
                notifications_enabled,
                is_auto_pay_enabled,
                is_pinned,
                is_active,
                memo,
                sort_order,
                created_at,
                updated_at
                """)
            .eq("user_id", value: userID)
            .execute()
            .value
    }

    private func fetchRemotePaymentHistories(
        for userID: UUID,
        client: SupabaseClient
    ) async throws -> [BackupPaymentHistoryRow] {
        try await client
            .from(Self.paymentHistoriesTable)
            .select("""
                user_id,
                subscription_id,
                paid_at,
                scheduled_date,
                amount_snapshot,
                currency_code,
                is_auto_pay,
                status,
                created_at,
                updated_at
                """)
            .eq("user_id", value: userID)
            .eq("status", value: "paid")
            .execute()
            .value
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
        userID: UUID,
        sortOrder: Int
    ) -> BackupSubscriptionItemRow {
        let billingCycle = flattenBillingCycle(subscription.billingCycle)
        return BackupSubscriptionItemRow(
            id: subscription.id,
            user_id: userID,
            name: subscription.name,
            category: subscription.category.rawValue,
            amount: subscription.amount,
            is_amount_undecided: subscription.isAmountUndecided,
            currency_code: subscription.currencyCode,
            billing_cycle_kind: billingCycle.kind,
            billing_cycle_days: billingCycle.days,
            next_billing_date: subscription.nextBillingDate,
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
        from subscription: Subscription,
        userID: UUID
    ) -> [BackupPaymentHistoryRow] {
        let paidDates = Array(
            Set(
                (subscription.paymentHistoryDates + [subscription.lastPaymentDate].compactMap { $0 })
                    .map { Calendar.current.startOfDay(for: $0) }
            )
        ).sorted(by: <)

        return paidDates.map { paidAt in
            BackupPaymentHistoryRow(
                user_id: userID,
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

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
