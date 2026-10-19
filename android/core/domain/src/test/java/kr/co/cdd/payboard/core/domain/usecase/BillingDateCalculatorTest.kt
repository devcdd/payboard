package kr.co.cdd.payboard.core.domain.usecase

import kr.co.cdd.payboard.core.domain.model.BillingCycle
import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

class BillingDateCalculatorTest {
    private val zone = ZoneId.of("Asia/Seoul")

    private fun instant(year: Int, month: Int, day: Int) = LocalDate.of(year, month, day).atStartOfDay(zone).toInstant()

    private fun day(value: java.time.Instant) = value.atZone(zone).dayOfMonth

    @Test
    fun monthlyKeepsAnchorDayAcrossShortMonths() {
        var date = instant(2024, 1, 31)
        var anchor: Int? = null
        val days = mutableListOf<Int>()
        repeat(4) {
            anchor = BillingDateCalculator.resolvedAnchorDay(date, anchor, zone)
            date = BillingDateCalculator.advance(date, BillingCycle.Monthly, anchor, zone)
            days += day(date)
        }
        assertEquals(listOf(29, 31, 30, 31), days)
        assertEquals(30, day(BillingDateCalculator.rewind(date, BillingCycle.Monthly, anchor, zone)))
    }

    @Test
    fun rewindRestoresMonthEnd() {
        assertEquals(
            instant(2025, 3, 31),
            BillingDateCalculator.rewind(instant(2025, 4, 30), BillingCycle.Monthly, 31, zone),
        )
    }

    @Test
    fun staleAnchorFollowsEditedDate() {
        assertEquals(15, BillingDateCalculator.resolvedAnchorDay(instant(2025, 5, 15), 31, zone))
    }

    @Test
    fun yearlyLeapDay() {
        var date = instant(2024, 2, 29)
        repeat(4) { date = BillingDateCalculator.advance(date, BillingCycle.Yearly, 29, zone) }
        assertEquals(instant(2028, 2, 29), date)
    }
}
