package kr.co.cdd.payboard.core.data.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

enum class NotificationPermissionAction {
    REQUEST_PERMISSION,
    OPEN_SETTINGS,
}

enum class NotificationSettingsNotice {
    TEST_SENT,
    TEST_FAILED,
    PERMISSION_REQUIRED,
}

data class NotificationSettingsState(
    val isPermissionGranted: Boolean = true,
    val areSystemNotificationsEnabled: Boolean = true,
    val action: NotificationPermissionAction? = null,
    val notice: NotificationSettingsNotice? = null,
)

class NotificationSettingsManager(
    context: Context,
) {
    private val appContext = context.applicationContext
    private val notificationManager = NotificationManagerCompat.from(appContext)
    private val _state = MutableStateFlow(currentState())
    val state: StateFlow<NotificationSettingsState> = _state.asStateFlow()

    fun refreshState() {
        _state.value = currentState(notice = _state.value.notice)
    }

    fun onPermissionRequestResult(granted: Boolean) {
        _state.value = currentState(
            notice = if (granted) _state.value.notice else NotificationSettingsNotice.PERMISSION_REQUIRED,
        )
    }

    fun clearNotice() {
        _state.value = _state.value.copy(notice = null)
    }

    fun openNotificationSettings() {
        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, appContext.packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        appContext.startActivity(intent)
    }

    fun sendTestNotification() {
        val state = currentState()
        if (state.action != null) {
            _state.value = state.copy(notice = NotificationSettingsNotice.PERMISSION_REQUIRED)
            return
        }

        runCatching {
            ensureChannel()
            notificationManager.notify(
                TEST_NOTIFICATION_ID,
                NotificationCompat.Builder(appContext, TEST_CHANNEL_ID)
                    .setSmallIcon(android.R.drawable.ic_dialog_info)
                    .setContentTitle("PayBoard")
                    .setContentText("PayBoard test reminder")
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                    .setAutoCancel(true)
                    .build(),
            )
        }.onSuccess {
            _state.value = currentState(notice = NotificationSettingsNotice.TEST_SENT)
        }.onFailure {
            _state.value = currentState(notice = NotificationSettingsNotice.TEST_FAILED)
        }
    }

    private fun currentState(
        notice: NotificationSettingsNotice? = null,
    ): NotificationSettingsState {
        val permissionGranted = hasNotificationPermission()
        val systemEnabled = notificationManager.areNotificationsEnabled()
        val action = when {
            !permissionGranted -> NotificationPermissionAction.REQUEST_PERMISSION
            !systemEnabled -> NotificationPermissionAction.OPEN_SETTINGS
            else -> null
        }
        return NotificationSettingsState(
            isPermissionGranted = permissionGranted,
            areSystemNotificationsEnabled = systemEnabled,
            action = action,
            notice = notice,
        )
    }

    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            appContext,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = appContext.getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(TEST_CHANNEL_ID)
        if (existing != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                TEST_CHANNEL_ID,
                "PayBoard Reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Test reminders and subscription notifications"
            },
        )
    }

    companion object {
        private const val TEST_CHANNEL_ID = "payboard.reminders"
        private const val TEST_NOTIFICATION_ID = 1001
    }
}
