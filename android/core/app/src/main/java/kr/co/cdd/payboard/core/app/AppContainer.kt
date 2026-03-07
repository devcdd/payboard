package kr.co.cdd.payboard.core.app

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import kr.co.cdd.payboard.core.data.repository.FileSubscriptionRepository
import kr.co.cdd.payboard.core.data.settings.UserPreferencesDataStore
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository
import kr.co.cdd.payboard.core.domain.repository.UserPreferencesRepository

class AppContainer(
    context: Context,
) {
    val subscriptionRepository: SubscriptionRepository = FileSubscriptionRepository(context)
    val userPreferencesRepository: UserPreferencesRepository = UserPreferencesDataStore(context)
}

@Composable
fun rememberAppContainer(): AppContainer {
    val context = LocalContext.current.applicationContext
    return remember(context) { AppContainer(context) }
}
