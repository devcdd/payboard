package kr.co.cdd.payboard.core.domain.model

enum class ReminderOption(val daysBefore: Int, val label: String) {
    ONE_DAY(1, "1 day before"),
    THREE_DAYS(3, "3 days before"),
    SEVEN_DAYS(7, "7 days before"),
}
