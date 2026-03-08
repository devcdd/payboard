package kr.co.cdd.payboard.feature.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kr.co.cdd.payboard.core.data.backup.BackupAuthManager
import kr.co.cdd.payboard.core.data.backup.BackupAuthState
import kr.co.cdd.payboard.core.data.notifications.NotificationSettingsManager
import kr.co.cdd.payboard.core.data.notifications.NotificationSettingsState
import kr.co.cdd.payboard.core.domain.model.AppAppearance
import kr.co.cdd.payboard.core.domain.model.AppLanguage
import kr.co.cdd.payboard.core.domain.model.InitialScreen
import kr.co.cdd.payboard.core.domain.model.ReminderOption
import kr.co.cdd.payboard.core.domain.model.UserPreferences
import kr.co.cdd.payboard.core.domain.repository.UserPreferencesRepository

class SettingsViewModel(
    private val repository: UserPreferencesRepository,
    private val backupAuthManager: BackupAuthManager,
    private val notificationSettingsManager: NotificationSettingsManager,
) : ViewModel() {
    val preferences: StateFlow<UserPreferences> = repository.preferences.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = UserPreferences(),
    )
    val backupAuthState: StateFlow<BackupAuthState> = backupAuthManager.state
    val notificationSettingsState: StateFlow<NotificationSettingsState> = notificationSettingsManager.state

    fun setAppearance(appearance: AppAppearance) {
        viewModelScope.launch { repository.setAppearance(appearance) }
    }

    fun setLanguage(language: AppLanguage) {
        viewModelScope.launch { repository.setLanguage(language) }
    }

    fun setInitialScreen(screen: InitialScreen) {
        viewModelScope.launch { repository.setInitialScreen(screen) }
    }

    fun setBoardSearchVisible(visible: Boolean) {
        viewModelScope.launch { repository.setBoardSearchVisible(visible) }
    }

    fun setPushNotificationsEnabled(enabled: Boolean) {
        viewModelScope.launch { repository.setPushNotificationsEnabled(enabled) }
    }

    fun toggleReminderOption(option: ReminderOption, isEnabled: Boolean) {
        val next = preferences.value.reminderOptions.toMutableSet()
        if (isEnabled) {
            next += option
        } else {
            next -= option
        }
        viewModelScope.launch { repository.setReminderOptions(next) }
    }

    fun setReminderTime(hour: Int, minute: Int) {
        viewModelScope.launch { repository.setReminderTime(hour, minute) }
    }

    fun signInWithKakao() {
        viewModelScope.launch { backupAuthManager.signInWithKakao() }
    }

    fun signOutBackup() {
        viewModelScope.launch { backupAuthManager.signOut() }
    }

    fun refreshBackupState() {
        backupAuthManager.refreshState()
    }

    fun clearBackupNotice() {
        backupAuthManager.clearNotice()
    }

    fun uploadBackup() {
        viewModelScope.launch { backupAuthManager.uploadBackup() }
    }

    fun restoreLatestBackup() {
        viewModelScope.launch { backupAuthManager.restoreLatestBackup() }
    }

    fun deleteBackupAccount() {
        viewModelScope.launch { backupAuthManager.deleteAccount() }
    }

    fun confirmRestoreAfterSignIn() {
        backupAuthManager.confirmRestoreAfterSignIn()
    }

    fun skipRestoreAfterSignIn() {
        backupAuthManager.skipRestoreAfterSignIn()
    }

    fun refreshNotificationState() {
        notificationSettingsManager.refreshState()
    }

    fun onNotificationPermissionResult(granted: Boolean) {
        notificationSettingsManager.onPermissionRequestResult(granted)
    }

    fun clearNotificationNotice() {
        notificationSettingsManager.clearNotice()
    }

    fun openNotificationSettings() {
        notificationSettingsManager.openNotificationSettings()
    }

    fun sendTestReminder() {
        notificationSettingsManager.sendTestNotification()
    }

    companion object {
        fun factory(
            repository: UserPreferencesRepository,
            backupAuthManager: BackupAuthManager,
            notificationSettingsManager: NotificationSettingsManager,
        ): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return SettingsViewModel(repository, backupAuthManager, notificationSettingsManager) as T
                }
            }
    }
}
