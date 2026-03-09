package kr.co.cdd.payboard.core.data.local

import android.content.Context
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import kr.co.cdd.payboard.core.domain.model.BillingCycle
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.model.SubscriptionCategory
import java.io.File
import java.math.BigDecimal
import java.time.Instant
import java.util.UUID

internal class LocalJsonStore(
    context: Context,
    fileName: String = "subscriptions.json",
) {
    private val file = File(context.filesDir, fileName)
    private val json = Json {
        prettyPrint = true
        ignoreUnknownKeys = true
    }

    fun load(): List<Subscription> {
        if (!file.exists()) {
            return emptyList()
        }
        return json.decodeFromString<List<SubscriptionRecord>>(file.readText())
            .map(SubscriptionRecord::toDomain)
    }

    fun save(subscriptions: List<Subscription>) {
        val payload = subscriptions.map(Subscription::toRecord)
        file.writeText(json.encodeToString(payload))
    }
}

@Serializable
private data class SubscriptionRecord(
    val id: String,
    val name: String,
    val category: String,
    val amount: String,
    val isAmountUndecided: Boolean,
    val currencyCode: String,
    val billingCycleType: String,
    val billingCycleDays: Int? = null,
    val nextBillingDate: String,
    val lastPaymentDate: String? = null,
    val paymentHistoryDates: List<String> = emptyList(),
    val iconKey: String,
    val iconColorKey: String,
    val customCategoryName: String? = null,
    val notificationsEnabled: Boolean,
    val isAutoPayEnabled: Boolean,
    val isPinned: Boolean,
    val isActive: Boolean,
    val memo: String? = null,
    val createdAt: String,
    val updatedAt: String,
)

private fun SubscriptionRecord.toDomain(): Subscription = Subscription(
    id = UUID.fromString(id),
    name = name,
    category = SubscriptionCategory.valueOf(category),
    amount = BigDecimal(amount),
    isAmountUndecided = isAmountUndecided,
    currencyCode = currencyCode,
    billingCycle = when (billingCycleType) {
        "monthly" -> BillingCycle.Monthly
        "yearly" -> BillingCycle.Yearly
        else -> BillingCycle.CustomDays(billingCycleDays ?: 30)
    },
    nextBillingDate = Instant.parse(nextBillingDate),
    lastPaymentDate = lastPaymentDate?.let(Instant::parse),
    paymentHistoryDates = paymentHistoryDates.map(Instant::parse),
    iconKey = iconKey,
    iconColorKey = iconColorKey,
    customCategoryName = customCategoryName,
    notificationsEnabled = notificationsEnabled,
    isAutoPayEnabled = isAutoPayEnabled,
    isPinned = isPinned,
    isActive = isActive,
    memo = memo,
    createdAt = Instant.parse(createdAt),
    updatedAt = Instant.parse(updatedAt),
)

private fun Subscription.toRecord(): SubscriptionRecord = SubscriptionRecord(
    id = id.toString(),
    name = name,
    category = category.name,
    amount = amount.toPlainString(),
    isAmountUndecided = isAmountUndecided,
    currencyCode = currencyCode,
    billingCycleType = when (billingCycle) {
        BillingCycle.Monthly -> "monthly"
        BillingCycle.Yearly -> "yearly"
        is BillingCycle.CustomDays -> "custom"
    },
    billingCycleDays = (billingCycle as? BillingCycle.CustomDays)?.days,
    nextBillingDate = nextBillingDate.toString(),
    lastPaymentDate = lastPaymentDate?.toString(),
    paymentHistoryDates = paymentHistoryDates.map(Instant::toString),
    iconKey = iconKey,
    iconColorKey = iconColorKey,
    customCategoryName = customCategoryName,
    notificationsEnabled = notificationsEnabled,
    isAutoPayEnabled = isAutoPayEnabled,
    isPinned = isPinned,
    isActive = isActive,
    memo = memo,
    createdAt = createdAt.toString(),
    updatedAt = updatedAt.toString(),
)
