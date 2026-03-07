package kr.co.cdd.payboard.core.domain.usecase

import kr.co.cdd.payboard.core.domain.model.BillingCycle
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

object BillingDateCalculator {
    fun advance(from: Instant, cycle: BillingCycle, zoneId: ZoneId = ZoneId.systemDefault()): Instant {
        val zoned = ZonedDateTime.ofInstant(from, zoneId)
        return when (cycle) {
            BillingCycle.Monthly -> zoned.plusMonths(1).toInstant()
            BillingCycle.Yearly -> zoned.plusYears(1).toInstant()
            is BillingCycle.CustomDays -> zoned.plusDays(cycle.days.toLong().coerceAtLeast(1)).toInstant()
        }
    }
}
