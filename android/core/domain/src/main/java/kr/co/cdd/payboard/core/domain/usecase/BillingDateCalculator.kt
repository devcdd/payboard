package kr.co.cdd.payboard.core.domain.usecase

import kr.co.cdd.payboard.core.domain.model.BillingCycle
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

object BillingDateCalculator {
    fun advance(
        from: Instant,
        cycle: BillingCycle,
        anchorDay: Int? = null,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Instant = shift(from, 1, cycle, anchorDay, zoneId)

    fun rewind(
        from: Instant,
        cycle: BillingCycle,
        anchorDay: Int? = null,
        zoneId: ZoneId = ZoneId.systemDefault(),
    ): Instant = shift(from, -1, cycle, anchorDay, zoneId)

    /**
     * 월말 보정(31일 → 2월 28일)으로 줄어든 날짜에서도 원래 결제 일자를 돌려준다.
     * 저장된 기준일이 날짜와 맞지 않으면(사용자가 날짜를 직접 바꾼 경우) 날짜의 일자를 따른다.
     */
    fun resolvedAnchorDay(date: Instant, anchorDay: Int?, zoneId: ZoneId = ZoneId.systemDefault()): Int {
        val localDate = date.atZone(zoneId).toLocalDate()
        val day = localDate.dayOfMonth
        if (anchorDay == null || anchorDay !in 1..31) return day
        return if (minOf(anchorDay, localDate.lengthOfMonth()) == day) anchorDay else day
    }

    private fun shift(from: Instant, cycles: Long, cycle: BillingCycle, anchorDay: Int?, zoneId: ZoneId): Instant {
        val zoned = ZonedDateTime.ofInstant(from, zoneId)
        return when (cycle) {
            BillingCycle.Monthly -> shiftMonths(zoned, cycles, resolvedAnchorDay(from, anchorDay, zoneId))
            BillingCycle.Yearly -> shiftMonths(zoned, cycles * 12, resolvedAnchorDay(from, anchorDay, zoneId))
            is BillingCycle.CustomDays -> zoned.plusDays(cycles * cycle.days.toLong().coerceAtLeast(1)).toInstant()
        }
    }

    private fun shiftMonths(zoned: ZonedDateTime, months: Long, anchorDay: Int): Instant {
        val moved = zoned.plusMonths(months)
        return moved.withDayOfMonth(minOf(anchorDay, moved.toLocalDate().lengthOfMonth())).toInstant()
    }
}
