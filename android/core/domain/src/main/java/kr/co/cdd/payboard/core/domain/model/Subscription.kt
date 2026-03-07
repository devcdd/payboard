package kr.co.cdd.payboard.core.domain.model

import java.math.BigDecimal
import java.time.Instant
import java.util.UUID

enum class SubscriptionCategory(val label: String) {
    VIDEO("Video"),
    MUSIC("Music"),
    PRODUCTIVITY("Productivity"),
    CLOUD("Cloud"),
    HOUSING("Housing"),
    SHOPPING("Shopping"),
    GAMING("Gaming"),
    FINANCE("Finance"),
    EDUCATION("Education"),
    HEALTH("Health"),
    OTHER("Other"),
}

sealed interface BillingCycle {
    val dayInterval: Int

    data object Monthly : BillingCycle {
        override val dayInterval: Int = 30
    }

    data object Yearly : BillingCycle {
        override val dayInterval: Int = 365
    }

    data class CustomDays(val days: Int) : BillingCycle {
        override val dayInterval: Int = days.coerceAtLeast(1)
    }
}

data class Subscription(
    val id: UUID = UUID.randomUUID(),
    val name: String,
    val category: SubscriptionCategory,
    val amount: BigDecimal,
    val isAmountUndecided: Boolean = false,
    val currencyCode: String = "KRW",
    val billingCycle: BillingCycle,
    val nextBillingDate: Instant,
    val lastPaymentDate: Instant? = null,
    val paymentHistoryDates: List<Instant> = emptyList(),
    val iconKey: String,
    val iconColorKey: String = "blue",
    val customCategoryName: String? = null,
    val notificationsEnabled: Boolean = true,
    val isAutoPayEnabled: Boolean = false,
    val isPinned: Boolean = false,
    val isActive: Boolean = true,
    val memo: String? = null,
    val createdAt: Instant = Instant.now(),
    val updatedAt: Instant = Instant.now(),
) {
    fun validate() {
        require(name.isNotBlank()) { "Subscription name is required." }
        require(isAmountUndecided || amount > BigDecimal.ZERO) { "Amount must be greater than zero." }
    }
}
