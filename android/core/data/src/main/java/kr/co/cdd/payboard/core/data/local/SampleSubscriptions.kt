package kr.co.cdd.payboard.core.data.local

import java.math.BigDecimal
import java.time.Instant
import java.time.temporal.ChronoUnit
import kr.co.cdd.payboard.core.domain.model.BillingCycle
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.model.SubscriptionCategory

internal object SampleSubscriptions {
    fun initial(): List<Subscription> {
        val now = Instant.now()
        return listOf(
            Subscription(
                name = "Netflix",
                category = SubscriptionCategory.VIDEO,
                amount = BigDecimal("17000"),
                billingCycle = BillingCycle.Monthly,
                nextBillingDate = now.plus(3, ChronoUnit.DAYS),
                iconKey = "N",
                iconColorKey = "red",
            ),
            Subscription(
                name = "Spotify",
                category = SubscriptionCategory.MUSIC,
                amount = BigDecimal("10900"),
                billingCycle = BillingCycle.Monthly,
                nextBillingDate = now.plus(8, ChronoUnit.DAYS),
                iconKey = "S",
                iconColorKey = "green",
            ),
            Subscription(
                name = "iCloud+",
                category = SubscriptionCategory.CLOUD,
                amount = BigDecimal("4400"),
                billingCycle = BillingCycle.Monthly,
                nextBillingDate = now.plus(14, ChronoUnit.DAYS),
                iconKey = "i",
                iconColorKey = "blue",
            ),
        )
    }
}
