package kr.co.cdd.payboard.core.domain.model

enum class AppAppearance(val label: String) {
    SYSTEM("System"),
    LIGHT("Light"),
    DARK("Dark"),
}

enum class AppLanguage(val code: String, val label: String) {
    KOREAN("ko", "한국어"),
    ENGLISH("en", "English"),
}

enum class InitialScreen(val label: String) {
    BOARD("Board"),
    CALENDAR("Calendar"),
}

data class UserPreferences(
    val appearance: AppAppearance = AppAppearance.SYSTEM,
    val language: AppLanguage = AppLanguage.KOREAN,
    val reminderOptions: Set<ReminderOption> = setOf(ReminderOption.THREE_DAYS),
    val reminderHour: Int = 9,
    val reminderMinute: Int = 0,
    val pushNotificationsEnabled: Boolean = true,
    val boardSearchVisible: Boolean = true,
    val initialScreen: InitialScreen = InitialScreen.BOARD,
)
