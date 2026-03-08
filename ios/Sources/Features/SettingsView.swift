import SwiftUI
import Domain
import DesignSystem
import AuthenticationServices
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @State private var appleSignInCoordinator: AppleSignInCoordinator?
    @State private var isShowingRestoreConfirm = false
    @State private var isShowingDeleteAccountConfirm = false

    public init(viewModel: SettingsViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            List {
                Section("settings.section.permission") {
                    Toggle(
                        "settings.push.usage",
                        isOn: Binding(
                            get: { viewModel.isPushNotificationsEnabled },
                            set: { isEnabled in
                                Task { await viewModel.setPushNotificationsEnabled(isEnabled) }
                            }
                        )
                    )

                    Text("settings.push.rationale")
                        .font(.caption)
                        .foregroundStyle(Color.payMuted)

                    if let messageKey = viewModel.pushNotificationMessageKey {
                        Text(LocalizedStringKey(messageKey))
                            .font(.caption)
                            .foregroundStyle(Color.payDanger)
                    }

                    if let actionButtonKey = viewModel.pushPermissionActionButtonKey {
                        Button(LocalizedStringKey(actionButtonKey)) {
                            Task { await viewModel.handlePushPermissionAction() }
                        }
                        .font(.caption.weight(.semibold))
                    }
                }

                Section("settings.section.backup") {
                    if !viewModel.isBackupConfigured {
                        Text("settings.backup.notConfigured")
                            .font(.caption)
                            .foregroundStyle(Color.payDanger)

                        Text(verbatim: viewModel.backupConfigurationDebugText)
                            .font(.caption2)
                            .foregroundStyle(Color.payMuted)
                            .textSelection(.enabled)
                    } else if viewModel.isBackupSignedIn {
                        if let account = viewModel.backupAccountIdentifier {
                            LabeledContent("settings.backup.account") {
                                Text(account)
                                    .font(.caption)
                                    .foregroundStyle(Color.payMuted)
                            }
                        }

                        if let latestBackupAtText = viewModel.latestBackupAtText {
                            Text(String(format: NSLocalizedString("settings.backup.latestAt", comment: ""), latestBackupAtText))
                                .font(.caption)
                                .foregroundStyle(Color.payMuted)
                        } else {
                            Text("settings.backup.latestAt.empty")
                                .font(.caption)
                                .foregroundStyle(Color.payMuted)
                        }

                        Button("settings.backup.upload.button") {
                            Task { await viewModel.uploadBackup() }
                        }
                        .disabled(viewModel.isBackupSyncInProgress || viewModel.isAccountDeletionInProgress)

                        Button("settings.backup.restore.button") {
                            isShowingRestoreConfirm = true
                        }
                        .disabled(viewModel.isBackupSyncInProgress || viewModel.isAccountDeletionInProgress)

                        Button("settings.backup.signOut") {
                            Task { await viewModel.signOutBackup() }
                        }
                        .disabled(viewModel.isBackupSyncInProgress || viewModel.isAccountDeletionInProgress)

                        Button("settings.backup.deleteAccount", role: .destructive) {
                            isShowingDeleteAccountConfirm = true
                        }
                        .disabled(viewModel.isBackupSyncInProgress || viewModel.isAccountDeletionInProgress)
                    } else {
                        backupSignInButtons
                    }

                    if let messageKey = viewModel.backupMessageKey {
                        Text(LocalizedStringKey(messageKey))
                            .font(.caption)
                            .foregroundStyle(isBackupErrorMessage(messageKey) ? Color.payDanger : Color.payMuted)
                    }

                    if viewModel.isAccountDeletionInProgress {
                        ProgressView("settings.backup.deleteAccount.inProgress")
                            .font(.caption)
                    } else if viewModel.isBackupSignInInProgress {
                        ProgressView("settings.backup.signIn.inProgress")
                            .font(.caption)
                    } else if viewModel.isBackupSyncInProgress {
                        ProgressView("settings.backup.sync.inProgress")
                            .font(.caption)
                    }

                    #if DEBUG
                    if let backupErrorDebugText = viewModel.backupErrorDebugText {
                        Text(verbatim: backupErrorDebugText)
                            .font(.caption2)
                            .foregroundStyle(Color.payMuted)
                            .textSelection(.enabled)
                    }
                    #endif
                }

                Section("settings.section.reminder") {
                    ForEach(ReminderOption.allCases, id: \.self) { option in
                        Toggle(LocalizedStringKey(option.labelKey), isOn: Binding(
                            get: { viewModel.selectedOptions.contains(option) },
                            set: { isOn in
                                if isOn {
                                    viewModel.selectedOptions.insert(option)
                                } else {
                                    viewModel.selectedOptions.remove(option)
                                }
                            }
                        ))
                    }

                    DatePicker(
                        "settings.reminder.time",
                        selection: $viewModel.reminderTime,
                        displayedComponents: .hourAndMinute
                    )

                    Button("settings.reminder.test.button") {
                        Task { await viewModel.sendTestReminder() }
                    }
                    .disabled(!viewModel.isPushNotificationsEnabled)

                    if let messageKey = viewModel.testReminderMessageKey {
                        Text(LocalizedStringKey(messageKey))
                            .font(.caption)
                            .foregroundStyle(Color.payMuted)
                    }
                }

                Section("settings.section.language") {
                    Picker("settings.language.picker", selection: $viewModel.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(LocalizedStringKey(language.labelKey)).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("settings.section.appearance") {
                    Picker("settings.appearance.picker", selection: $viewModel.appAppearance) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(LocalizedStringKey(appearance.labelKey)).tag(appearance)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("settings.section.board") {
                    Picker("settings.initialScreen.picker", selection: $viewModel.initialScreen) {
                        ForEach(InitialScreen.allCases) { screen in
                            Text(LocalizedStringKey(screen.labelKey)).tag(screen)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("settings.initialScreen.caption")
                        .font(.caption)
                        .foregroundStyle(Color.payMuted)

                    Divider()

                    Toggle("settings.board.searchVisible", isOn: $viewModel.isBoardSearchVisible)
                    Text("settings.board.searchVisible.caption")
                        .font(.caption)
                        .foregroundStyle(Color.payMuted)
                }

                Section("settings.section.contact") {
                    if let emailURL = URL(string: "mailto:developer.cdd@gmail.com") {
                        Button {
                            openURL(emailURL)
                        } label: {
                            Label {
                                Text("settings.contact.email")
                                    .foregroundStyle(Color.payAccent)
                            } icon: {
                                Image(systemName: "envelope")
                                    .foregroundStyle(Color.payMuted)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if let instagramURL = URL(string: "https://www.instagram.com/payboard.app/") {
                        Button {
                            openURL(instagramURL)
                        } label: {
                            Label {
                                Text("settings.contact.instagram")
                                    .foregroundStyle(Color.payAccent)
                            } icon: {
                                Image(systemName: "camera")
                                    .foregroundStyle(Color.payMuted)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("settings.contact.caption")
                        .font(.caption)
                        .foregroundStyle(Color.payMuted)
                }
            }
            .listStyle(.plain)
            .navigationTitle("settings.title")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .alert("settings.backup.restore.confirm.title", isPresented: $isShowingRestoreConfirm) {
                Button("common.cancel", role: .cancel) {}
                Button("settings.backup.restore.confirm.confirm", role: .destructive) {
                    Task { await viewModel.restoreLatestBackup() }
                }
            } message: {
                Text("settings.backup.restore.confirm.message")
            }
            .alert("settings.backup.deleteAccount.confirm.title", isPresented: $isShowingDeleteAccountConfirm) {
                Button("common.cancel", role: .cancel) {}
                Button("settings.backup.deleteAccount.confirm.confirm", role: .destructive) {
                    Task { await viewModel.deleteAccount() }
                }
            } message: {
                Text(viewModel.deleteAccountConfirmationMessage)
            }
            .alert("settings.backup.signIn.restorePrompt.title", isPresented: $viewModel.isShowingRestorePromptAfterSignIn) {
                Button("settings.backup.signIn.restorePrompt.skip", role: .cancel) {
                    viewModel.skipRestoreAfterSignIn()
                }
                Button("settings.backup.signIn.restorePrompt.restore", role: .destructive) {
                    Task { await viewModel.confirmRestoreAfterSignIn() }
                }
            } message: {
                Text("settings.backup.signIn.restorePrompt.message")
            }
            .task {
                await viewModel.refreshPushPermissionState()
            }
        }
    }

    private var appleSignInImageButton: some View {
        Button {
            startAppleSignIn()
        } label: {
            Image(appleSignInAssetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
            }
        .buttonStyle(.plain)
        .aspectRatio(800.0 / 128.0, contentMode: .fit)
        .contentShape(Rectangle())
        .accessibilityLabel("Sign in with Apple")
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var kakaoSignInImageButton: some View {
        Button {
            Task { await viewModel.signInWithKakao() }
        } label: {
            Image(kakaoSignInAssetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .aspectRatio(800.0 / 128.0, contentMode: .fit)
        .contentShape(Rectangle())
        .accessibilityLabel(Text("settings.backup.signIn.kakao.accessibilityLabel"))
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
        .listRowBackground(Color.clear)
        .disabled(viewModel.isBackupSignInInProgress)
    }

    private var backupSignInButtons: some View {
        VStack(spacing: 12) {
            kakaoSignInImageButton
            appleSignInImageButton
        }
    }

    private var appleSignInAssetName: String {
        let isKorean = locale.language.languageCode?.identifier == "ko"
        switch (isKorean, colorScheme == .dark) {
        case (true, true):
            return "button_apple_login_kr_dark"
        case (true, false):
            return "button_apple_login_kr"
        case (false, true):
            return "button_apple_login_us_dark"
        case (false, false):
            return "button_apple_login_us"
        }
    }

    private var kakaoSignInAssetName: String {
        locale.language.languageCode?.identifier == "ko" ? "button_kakao_login_kr" : "button_kakao_login_us"
    }

    private func startAppleSignIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        viewModel.prepareAppleSignInRequest(request)

        let coordinator = AppleSignInCoordinator { result in
            Task { await viewModel.handleAppleSignInCompletion(result) }
            appleSignInCoordinator = nil
        }
        appleSignInCoordinator = coordinator

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        controller.performRequests()
    }

    private func isBackupErrorMessage(_ messageKey: String) -> Bool {
        messageKey.hasSuffix("failed") || messageKey.hasSuffix("notConfigured")
    }
}

private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let onCompletion: (Result<ASAuthorization, any Error>) -> Void

    init(onCompletion: @escaping (Result<ASAuthorization, any Error>) -> Void) {
        self.onCompletion = onCompletion
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        onCompletion(.success(authorization))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: any Error) {
        onCompletion(.failure(error))
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: \.isKeyWindow) {
            return keyWindow
        }
        if let keyWindow = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return keyWindow
        }
        return ASPresentationAnchor()
        #elseif os(macOS)
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}

#Preview("Settings") {
    SettingsPreviewContainer()
}

private struct SettingsPreviewContainer: View {
    @StateObject private var viewModel = SettingsViewModel(scheduler: NoopNotificationScheduler())

    var body: some View {
        SettingsView(viewModel: viewModel)
    }
}
