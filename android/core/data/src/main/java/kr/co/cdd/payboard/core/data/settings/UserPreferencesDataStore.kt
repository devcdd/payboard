package kr.co.cdd.payboard.core.data.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kr.co.cdd.payboard.core.domain.model.AppAppearance
import kr.co.cdd.payboard.core.domain.model.AppLanguage
import kr.co.cdd.payboard.core.domain.model.InitialScreen
import kr.co.cdd.payboard.core.domain.model.ReminderOption
import kr.co.cdd.payboard.core.domain.model.UserPreferences
import kr.co.cdd.payboard.core.domain.repository.UserPreferencesRepository

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "payboard_preferences")

class UserPreferencesDataStore(
    context: Context,
) : UserPreferencesRepository {
    private val dataStore = context.applicationContext.dataStore

    override val preferences: Flow<UserPreferences> = dataStore.data.map { prefs ->
        UserPreferences(
            appearance = prefs[Keys.Appearance]?.let(AppAppearance::valueOf) ?: AppAppearance.SYSTEM,
            language = prefs[Keys.Language]?.let(AppLanguage::valueOf) ?: AppLanguage.KOREAN,
            reminderOptions = prefs[Keys.ReminderOptions]
                ?.mapNotNull { value -> ReminderOption.entries.find { it.name == value } }
                ?.toSet()
                ?.ifEmpty { setOf(ReminderOption.THREE_DAYS) }
                ?: setOf(ReminderOption.THREE_DAYS),
            reminderHour = prefs[Keys.ReminderHour] ?: 9,
            reminderMinute = prefs[Keys.ReminderMinute] ?: 0,
            pushNotificationsEnabled = prefs[Keys.PushNotificationsEnabled] ?: true,
            boardSearchVisible = prefs[Keys.BoardSearchVisible] ?: true,
            initialScreen = prefs[Keys.InitialScreen]?.let(InitialScreen::valueOf) ?: InitialScreen.BOARD,
        )
    }

    override suspend fun setAppearance(appearance: AppAppearance) {
        dataStore.edit { it[Keys.Appearance] = appearance.name }
    }

    override suspend fun setLanguage(language: AppLanguage) {
        dataStore.edit { it[Keys.Language] = language.name }
    }

    override suspend fun setReminderOptions(options: Set<ReminderOption>) {
        dataStore.edit { it[Keys.ReminderOptions] = options.map(ReminderOption::name).toSet() }
    }

    override suspend fun setReminderTime(hour: Int, minute: Int) {
        dataStore.edit {
            it[Keys.ReminderHour] = hour.coerceIn(0, 23)
            it[Keys.ReminderMinute] = minute.coerceIn(0, 59)
        }
    }

    override suspend fun setPushNotificationsEnabled(enabled: Boolean) {
        dataStore.edit { it[Keys.PushNotificationsEnabled] = enabled }
    }

    override suspend fun setBoardSearchVisible(visible: Boolean) {
        dataStore.edit { it[Keys.BoardSearchVisible] = visible }
    }

    override suspend fun setInitialScreen(screen: InitialScreen) {
        dataStore.edit { it[Keys.InitialScreen] = screen.name }
    }

    private object Keys {
        val Appearance = stringPreferencesKey("settings.appAppearance")
        val Language = stringPreferencesKey("settings.appLanguage")
        val ReminderOptions = stringSetPreferencesKey("settings.reminder.options")
        val ReminderHour = intPreferencesKey("settings.reminder.hour")
        val ReminderMinute = intPreferencesKey("settings.reminder.minute")
        val PushNotificationsEnabled = booleanPreferencesKey("settings.pushNotifications.enabled")
        val BoardSearchVisible = booleanPreferencesKey("settings.boardSearchVisible")
        val InitialScreen = stringPreferencesKey("settings.initialScreen")
    }
}
