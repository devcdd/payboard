package kr.co.cdd.payboard.feature.archive

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kr.co.cdd.payboard.core.data.backup.BackupAuthManager
import kr.co.cdd.payboard.core.data.notifications.SubscriptionReminderScheduler
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository
import kr.co.cdd.payboard.core.domain.repository.UserPreferencesRepository

class ArchiveViewModel(
    private val repository: SubscriptionRepository,
    private val backupAuthManager: BackupAuthManager,
    private val userPreferencesRepository: UserPreferencesRepository,
    private val reminderScheduler: SubscriptionReminderScheduler,
) : ViewModel() {
    val archivedSubscriptions: StateFlow<List<Subscription>> = repository.observeArchived().stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = emptyList(),
    )

    fun restore(subscription: Subscription) {
        viewModelScope.launch {
            repository.restore(subscription.id)
            val restored = repository.fetchAll().firstOrNull { it.id == subscription.id }
            if (restored != null) {
                reminderScheduler.syncSubscription(restored, userPreferencesRepository.preferences.first())
            }
            backupAuthManager.autoBackupAfterSubscriptionUpsert()
        }
    }

    fun delete(subscription: Subscription) {
        viewModelScope.launch {
            repository.delete(subscription.id)
            reminderScheduler.cancelSubscription(subscription.id)
            backupAuthManager.autoBackupAfterSubscriptionUpsert()
        }
    }

    companion object {
        fun factory(
            repository: SubscriptionRepository,
            backupAuthManager: BackupAuthManager,
            userPreferencesRepository: UserPreferencesRepository,
            reminderScheduler: SubscriptionReminderScheduler,
        ): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return ArchiveViewModel(
                        repository = repository,
                        backupAuthManager = backupAuthManager,
                        userPreferencesRepository = userPreferencesRepository,
                        reminderScheduler = reminderScheduler,
                    ) as T
                }
            }
    }
}
