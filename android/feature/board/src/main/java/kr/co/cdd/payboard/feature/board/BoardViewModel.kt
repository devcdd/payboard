package kr.co.cdd.payboard.feature.board

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kr.co.cdd.payboard.core.domain.model.BillingCycle
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository
import kr.co.cdd.payboard.core.domain.usecase.BillingDateCalculator
import java.time.Instant

enum class BoardDisplayMode {
    BOARD,
    CALENDAR,
}

enum class BoardFilter(val label: String) {
    ALL("All"),
    THIS_WEEK("This Week"),
    THIS_MONTH("This Month"),
}

data class BoardUiState(
    val subscriptions: List<Subscription> = emptyList(),
    val searchQuery: String = "",
    val selectedFilter: BoardFilter = BoardFilter.ALL,
)

class BoardViewModel(
    private val repository: SubscriptionRepository,
) : ViewModel() {
    private val searchQuery = MutableStateFlow("")
    private val selectedFilter = MutableStateFlow(BoardFilter.ALL)

    val uiState: StateFlow<BoardUiState> = combine(
        repository.observeActive(),
        searchQuery,
        selectedFilter,
    ) { subscriptions, query, filter ->
        BoardUiState(
            subscriptions = subscriptions.filter(query, filter),
            searchQuery = query,
            selectedFilter = filter,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = BoardUiState(),
    )

    fun updateSearchQuery(query: String) {
        searchQuery.value = query
    }

    fun updateFilter(filter: BoardFilter) {
        selectedFilter.value = filter
    }

    fun archive(subscription: Subscription) {
        viewModelScope.launch {
            repository.archive(subscription.id)
        }
    }

    fun markPaymentComplete(subscription: Subscription) {
        viewModelScope.launch {
            repository.update(
                subscription.copy(
                    lastPaymentDate = Instant.now(),
                    paymentHistoryDates = subscription.paymentHistoryDates + Instant.now(),
                    nextBillingDate = BillingDateCalculator.advance(subscription.nextBillingDate, subscription.billingCycle),
                    updatedAt = Instant.now(),
                ),
            )
        }
    }

    companion object {
        fun factory(repository: SubscriptionRepository): ViewModelProvider.Factory =
            object : ViewModelProvider.Factory {
                @Suppress("UNCHECKED_CAST")
                override fun <T : ViewModel> create(modelClass: Class<T>): T {
                    return BoardViewModel(repository) as T
                }
            }
    }
}

private fun List<Subscription>.filter(query: String, filter: BoardFilter): List<Subscription> {
    val now = Instant.now()
    val filteredByDate = when (filter) {
        BoardFilter.ALL -> this
        BoardFilter.THIS_WEEK -> filter { subscription ->
            subscription.nextBillingDate.isAfter(now.minusSeconds(1)) &&
                subscription.nextBillingDate.isBefore(now.plusSeconds(7 * 24 * 60 * 60L))
        }
        BoardFilter.THIS_MONTH -> filter { subscription ->
            subscription.nextBillingDate.isAfter(now.minusSeconds(1)) &&
                subscription.nextBillingDate.isBefore(now.plusSeconds(31 * 24 * 60 * 60L))
        }
    }
    if (query.isBlank()) return filteredByDate
    return filteredByDate.filter { subscription ->
        subscription.name.contains(query, ignoreCase = true) ||
            subscription.category.label.contains(query, ignoreCase = true)
    }
}
