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

@MainActor
public final class SettingsViewModel: ObservableObject {
    private static let appearanceKey = "settings.appAppearance"
    private static let languageKey = "settings.appLanguage"
    private static let reminderOptionsKey = "settings.reminder.options"
    private static let reminderHourKey = "settings.reminder.hour"
    private static let reminderMinuteKey = "settings.reminder.minute"
    private static let pushNotificationsEnabledKey = "settings.pushNotifications.enabled"
    private static let hasRequestedInitialNotificationPermissionKey = "settings.pushNotifications.hasRequestedInitialPermission"
    private static let latestBackupsTable = "subscription_latest_backups"
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
    @Published public private(set) var pushNotificationMessageKey: String?
    @Published public private(set) var pushPermissionActionButtonKey: String?
    @Published public private(set) var testReminderMessageKey: String?
    @Published public private(set) var isBackupConfigured: Bool
    @Published public private(set) var isBackupSignedIn = false
    @Published public private(set) var backupAccountIdentifier: String?
    @Published public private(set) var backupMessageKey: String?
    @Published public private(set) var backupErrorDebugText: String?
    @Published public private(set) var isBackupSyncInProgress = false
    @Published public var isShowingRestorePromptAfterSignIn = false
    @Published public private(set) var latestBackupAt: Date?

    private let scheduler: any NotificationScheduler
    private let repository: any SubscriptionRepository
    private let userDefaults: UserDefaults
    private let supabaseClient: SupabaseClient?
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

    public var backupConfigurationDebugText: String {
        let processEnvironment = ProcessInfo.processInfo.environment
        let envURL = processEnvironment["SUPABASE_URL"] ?? processEnvironment["INFOPLIST_KEY_SUPABASE_URL"]
        let envKey = processEnvironment["SUPABASE_ANON_KEY"] ?? processEnvironment["INFOPLIST_KEY_SUPABASE_ANON_KEY"]
        let bundleURL = Self.infoDictionaryStringValue(forPrimaryKey: "SUPABASE_URL", fallbackKey: "INFOPLIST_KEY_SUPABASE_URL")
        let bundleKey = Self.infoDictionaryStringValue(forPrimaryKey: "SUPABASE_ANON_KEY", fallbackKey: "INFOPLIST_KEY_SUPABASE_ANON_KEY")
        let normalizedURL = Self.normalizedSecretValue(envURL ?? bundleURL) ?? "<nil>"
        let normalizedKey = Self.normalizedSecretValue(envKey ?? bundleKey).map(Self.maskSecretValue) ?? "<nil>"

        return [
            "ENV SUPABASE_URL: \(envURL ?? "<nil>")",
            "BUNDLE SUPABASE_URL: \(bundleURL ?? "<nil>")",
            "ENV SUPABASE_ANON_KEY: \(envKey.map(Self.maskSecretValue) ?? "<nil>")",
            "BUNDLE SUPABASE_ANON_KEY: \(bundleKey.map(Self.maskSecretValue) ?? "<nil>")",
            "NORMALIZED URL: \(normalizedURL)",
            "NORMALIZED KEY: \(normalizedKey)",
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
            let subscriptions = try await repository.fetchAll()
            let row = BackupInsertRow(
                user_id: session.user.id,
                backup_version: 1,
                item_count: subscriptions.count,
                payload: subscriptions,
                payload_sha256: nil,
                device_id: nil,
                app_version: nil,
                updated_at: .now
            )
            try await supabaseClient
                .from(Self.latestBackupsTable)
                .upsert(row, onConflict: "user_id")
                .execute()
            latestBackupAt = .now
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
            let rows: [BackupStoredRow] = try await supabaseClient
                .from(Self.latestBackupsTable)
                .select("user_id,payload,item_count,created_at,updated_at")
                .eq("user_id", value: session.user.id)
                .limit(1)
                .execute()
                .value

            guard let latest = rows.first else {
                backupMessageKey = "settings.backup.restore.empty"
                backupErrorDebugText = nil
                return
            }

            try await replaceAllSubscriptions(with: latest.payload)
            let updated = try await repository.fetchAll()
            WidgetSnapshotStore.save(subscriptions: updated)
            backupMessageKey = "settings.backup.restore.success"
            backupErrorDebugText = nil
            latestBackupAt = latest.updated_at
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
            latestBackupAt = try await fetchLatestBackupRow(for: session.user.id, client: supabaseClient)?.updated_at
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

    private struct BackupInsertRow: Encodable {
        let user_id: UUID
        let backup_version: Int
        let item_count: Int
        let payload: [Subscription]
        let payload_sha256: String?
        let device_id: String?
        let app_version: String?
        let updated_at: Date
    }

    private struct BackupStoredRow: Decodable {
        let user_id: UUID
        let payload: [Subscription]
        let item_count: Int
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

    private func bootstrapBackupAfterSignIn() async {
        guard let supabaseClient else { return }

        do {
            let session = try await supabaseClient.auth.session
            if let _ = try await fetchLatestBackupRow(for: session.user.id, client: supabaseClient) {
                backupMessageKey = "settings.backup.signIn.restorePrompt"
                isShowingRestorePromptAfterSignIn = true
            } else {
                try await uploadCurrentDataAsBackup(for: session.user.id, client: supabaseClient)
                backupMessageKey = "settings.backup.signIn.autoBackupDone"
                latestBackupAt = .now
            }
        } catch {
            backupErrorDebugText = Self.describeBackupSyncError(error, operation: "post_sign_in_bootstrap")
        }
    }

    private func fetchLatestBackupRow(
        for userID: UUID,
        client: SupabaseClient
    ) async throws -> BackupStoredRow? {
        let rows: [BackupStoredRow] = try await client
            .from(Self.latestBackupsTable)
            .select("user_id,payload,item_count,created_at,updated_at")
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
        let subscriptions = try await repository.fetchAll()
        let row = BackupInsertRow(
            user_id: userID,
            backup_version: 1,
            item_count: subscriptions.count,
            payload: subscriptions,
            payload_sha256: nil,
            device_id: nil,
            app_version: nil,
            updated_at: .now
        )
        try await client
            .from(Self.latestBackupsTable)
            .upsert(row, onConflict: "user_id")
            .execute()
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
        let current = try await repository.fetchAll()
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
