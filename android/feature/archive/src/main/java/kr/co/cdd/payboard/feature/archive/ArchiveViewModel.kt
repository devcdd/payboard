package kr.co.cdd.payboard.feature.archive

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository

class ArchiveViewModel(
    private val repository: SubscriptionRepository,
) : ViewModel() {
    val archivedSubscriptions: StateFlow<List<Subscription>> = repository.observeArchived().stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = emptyList(),
    )

    fun restore(subscription: Subscription) {
        viewModelScope.launch {
            repository.restore(subscription.id)
        }
    }

    fun delete(subscription: Subscription) {
        viewModelScope.launch {
            repository.delete(subscription.id)
        }
    }

    companion object {
        fun factory(repository: SubscriptionRepository): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return ArchiveViewModel(repository) as T
                }
            }
    }
}
