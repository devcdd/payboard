package kr.co.cdd.payboard.core.app

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import kr.co.cdd.payboard.core.data.backup.BackupAuthManager
import kr.co.cdd.payboard.core.data.notifications.NotificationSettingsManager
import kr.co.cdd.payboard.core.data.repository.FileSubscriptionRepository
import kr.co.cdd.payboard.core.data.settings.UserPreferencesDataStore
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository
import kr.co.cdd.payboard.core.domain.repository.UserPreferencesRepository

class AppContainer(
    context: Context,
) {
    val subscriptionRepository: SubscriptionRepository = FileSubscriptionRepository(context)
    val userPreferencesRepository: UserPreferencesRepository = UserPreferencesDataStore(context)
    val backupAuthManager: BackupAuthManager = BackupAuthManager(context, subscriptionRepository)
    val notificationSettingsManager: NotificationSettingsManager = NotificationSettingsManager(context)

    fun handleAuthDeepLink(intent: Intent) {
        backupAuthManager.handleDeepLink(intent)
    }
}

@Composable
fun rememberAppContainer(): AppContainer {
    val context = LocalContext.current.applicationContext
    val existing = (context as? AppContainerOwner)?.appContainer
    return remember(context, existing) { existing ?: AppContainer(context) }
}

interface AppContainerOwner {
    val appContainer: AppContainer
}
