package kr.co.cdd.payboard.core.data.notifications

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.flow.first
import kr.co.cdd.payboard.core.data.repository.FileSubscriptionRepository
import kr.co.cdd.payboard.core.data.settings.UserPreferencesDataStore
import kr.co.cdd.payboard.core.domain.model.AppLanguage
import java.util.UUID

class SubscriptionReminderWorker(
    appContext: Context,
    params: WorkerParameters,
) : CoroutineWorker(appContext, params) {
    override suspend fun doWork(): Result {
        val subscriptionId = inputData.getString(SubscriptionReminderScheduler.INPUT_SUBSCRIPTION_ID)
            ?.let(UUID::fromString)
            ?: return Result.success()
        val daysBefore = inputData.getInt(SubscriptionReminderScheduler.INPUT_DAYS_BEFORE, -1)
        if (daysBefore < 0) return Result.success()
        val scheduledBillingEpochMillis = inputData.getLong(
            SubscriptionReminderScheduler.INPUT_SCHEDULED_BILLING_EPOCH_MILLIS,
            Long.MIN_VALUE,
        )
        if (scheduledBillingEpochMillis == Long.MIN_VALUE) return Result.success()

        val preferences = UserPreferencesDataStore(applicationContext).preferences.first()
        val subscription = FileSubscriptionRepository(applicationContext).fetchAll()
            .firstOrNull { it.id == subscriptionId }
            ?: return Result.success()

        if (!preferences.pushNotificationsEnabled || !subscription.isActive || !subscription.notificationsEnabled) {
            return Result.success()
        }
        if (subscription.nextBillingDate.toEpochMilli() != scheduledBillingEpochMillis) {
            return Result.success()
        }
        if (!hasNotificationPermission() || !NotificationManagerCompat.from(applicationContext).areNotificationsEnabled()) {
            return Result.success()
        }

        ensureChannel(preferences.language)

        val body = if (subscription.isAutoPayEnabled) {
            notificationAutoPayBody(preferences.language, subscription.name, daysBefore)
        } else {
            notificationReminderBody(preferences.language, subscription.name)
        }

        NotificationManagerCompat.from(applicationContext).notify(
            notificationId(subscriptionId, daysBefore),
            NotificationCompat.Builder(applicationContext, REMINDER_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(notificationReminderTitle(preferences.language))
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .build(),
        )
        return Result.success()
    }

    private fun ensureChannel(language: AppLanguage) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(REMINDER_CHANNEL_ID)
        if (existing != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                REMINDER_CHANNEL_ID,
                notificationChannelName(language),
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = notificationChannelDescription(language)
            },
        )
    }

    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            applicationContext,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun notificationId(subscriptionId: UUID, daysBefore: Int): Int =
        "$subscriptionId:$daysBefore".hashCode()

    private fun notificationChannelName(language: AppLanguage): String = when (language) {
        AppLanguage.KOREAN -> "PayBoard 리마인더"
        AppLanguage.ENGLISH -> "PayBoard Reminders"
    }

    private fun notificationChannelDescription(language: AppLanguage): String = when (language) {
        AppLanguage.KOREAN -> "정기 결제 리마인더와 테스트 알림"
        AppLanguage.ENGLISH -> "Subscription reminders and test notifications"
    }

    private fun notificationReminderTitle(language: AppLanguage): String = when (language) {
        AppLanguage.KOREAN -> "결제 예정 알림"
        AppLanguage.ENGLISH -> "Upcoming payment"
    }

    private fun notificationReminderBody(language: AppLanguage, subscriptionName: String): String {
        val format = when (language) {
            AppLanguage.KOREAN -> "%s 결제가 곧 예정되어 있습니다."
            AppLanguage.ENGLISH -> "%s payment is due soon."
        }
        return String.format(format, subscriptionName)
    }

    private fun notificationAutoPayBody(
        language: AppLanguage,
        subscriptionName: String,
        daysBefore: Int,
    ): String {
        val format = when (language) {
            AppLanguage.KOREAN -> when (daysBefore) {
                0 -> "%s 서비스가 오늘 자동이체 될 예정입니다."
                1 -> "%s 서비스가 내일 자동이체 될 예정입니다."
                2 -> "%s 서비스가 이틀 후 자동이체 될 예정입니다."
                else -> "%s 서비스가 자동이체 될 예정입니다."
            }
            AppLanguage.ENGLISH -> when (daysBefore) {
                0 -> "%s will be charged by auto pay today."
                1 -> "%s will be charged by auto pay tomorrow."
                2 -> "%s will be charged by auto pay in two days."
                else -> "%s will be charged by auto pay soon."
            }
        }
        return String.format(format, subscriptionName)
    }

    companion object {
        private const val REMINDER_CHANNEL_ID = "payboard.reminders"
    }
}
