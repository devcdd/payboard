package kr.co.cdd.payboard.core.domain.repository

import kotlinx.coroutines.flow.Flow
import kr.co.cdd.payboard.core.domain.model.AppAppearance
import kr.co.cdd.payboard.core.domain.model.AppLanguage
import kr.co.cdd.payboard.core.domain.model.InitialScreen
import kr.co.cdd.payboard.core.domain.model.ReminderOption
import kr.co.cdd.payboard.core.domain.model.UserPreferences

interface UserPreferencesRepository {
    val preferences: Flow<UserPreferences>

    suspend fun setAppearance(appearance: AppAppearance)
    suspend fun setLanguage(language: AppLanguage)
    suspend fun setReminderOptions(options: Set<ReminderOption>)
    suspend fun setReminderTime(hour: Int, minute: Int)
    suspend fun setPushNotificationsEnabled(enabled: Boolean)
    suspend fun setBoardSearchVisible(visible: Boolean)
    suspend fun setInitialScreen(screen: InitialScreen)
}
