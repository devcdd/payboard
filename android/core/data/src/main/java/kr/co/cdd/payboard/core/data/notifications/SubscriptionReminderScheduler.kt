package kr.co.cdd.payboard.core.data.notifications

import android.content.Context
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.time.Duration
import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.UUID
import kr.co.cdd.payboard.core.domain.model.ReminderOption
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.model.UserPreferences

class SubscriptionReminderScheduler(
    context: Context,
) {
    private val appContext = context.applicationContext
    private val workManager = WorkManager.getInstance(appContext)

    fun syncSubscription(subscription: Subscription, preferences: UserPreferences) {
        cancelSubscription(subscription.id)
        if (!shouldSchedule(subscription, preferences)) return

        preferences.reminderOptions.forEach { option ->
            enqueueReminder(subscription, preferences, option)
        }
    }

    fun syncAll(subscriptions: List<Subscription>, preferences: UserPreferences) {
        workManager.cancelAllWorkByTag(REMINDER_WORK_TAG)
        if (!preferences.pushNotificationsEnabled) return

        subscriptions
            .filter(Subscription::isActive)
            .forEach { subscription ->
                syncSubscription(subscription, preferences)
            }
    }

    fun cancelSubscription(subscriptionId: UUID) {
        ReminderOption.entries.forEach { option ->
            workManager.cancelUniqueWork(uniqueWorkName(subscriptionId, option.daysBefore))
        }
    }

    private fun enqueueReminder(
        subscription: Subscription,
        preferences: UserPreferences,
        option: ReminderOption,
    ) {
        val now = ZonedDateTime.now()
        val scheduledAt = subscription.nextBillingDate
            .atZone(ZoneId.systemDefault())
            .minusDays(option.daysBefore.toLong())
            .withHour(preferences.reminderHour)
            .withMinute(preferences.reminderMinute)
            .withSecond(0)
            .withNano(0)

        if (!scheduledAt.isAfter(now)) return

        val delay = Duration.between(now, scheduledAt)
        val request = OneTimeWorkRequestBuilder<SubscriptionReminderWorker>()
            .setInitialDelay(delay)
            .setInputData(
                Data.Builder()
                    .putString(INPUT_SUBSCRIPTION_ID, subscription.id.toString())
                    .putInt(INPUT_DAYS_BEFORE, option.daysBefore)
                    .putLong(INPUT_SCHEDULED_BILLING_EPOCH_MILLIS, subscription.nextBillingDate.toEpochMilli())
                    .build(),
            )
            .addTag(REMINDER_WORK_TAG)
            .addTag(subscriptionTag(subscription.id))
            .build()

        workManager.enqueueUniqueWork(
            uniqueWorkName(subscription.id, option.daysBefore),
            ExistingWorkPolicy.REPLACE,
            request,
        )
    }

    private fun shouldSchedule(
        subscription: Subscription,
        preferences: UserPreferences,
    ): Boolean = preferences.pushNotificationsEnabled &&
        subscription.isActive &&
        subscription.notificationsEnabled

    companion object {
        internal const val REMINDER_WORK_TAG = "subscription.reminder"
        internal const val INPUT_SUBSCRIPTION_ID = "subscription_id"
        internal const val INPUT_DAYS_BEFORE = "days_before"
        internal const val INPUT_SCHEDULED_BILLING_EPOCH_MILLIS = "scheduled_billing_epoch_millis"

        internal fun uniqueWorkName(subscriptionId: UUID, daysBefore: Int): String =
            "$REMINDER_WORK_TAG.${subscriptionId}.$daysBefore"

        internal fun subscriptionTag(subscriptionId: UUID): String =
            "$REMINDER_WORK_TAG.${subscriptionId}"
    }
}
