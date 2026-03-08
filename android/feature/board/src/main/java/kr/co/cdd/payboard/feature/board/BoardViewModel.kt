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
import java.util.UUID

enum class BoardDisplayMode {
    BOARD,
    CALENDAR,
}

enum class BoardFilter(
    val label: String,
    val storageValue: String,
) {
    ALL("All", "all"),
    THIS_WEEK("This Week", "thisWeek"),
    THIS_MONTH("This Month", "thisMonth");

    companion object {
        fun fromStorageValue(rawValue: String?): BoardFilter =
            entries.firstOrNull { it.storageValue == rawValue } ?: ALL
    }
}

enum class BoardSortOption(val storageValue: String) {
    NEXT_BILLING_ASC("nextBillingAsc"),
    NEXT_BILLING_DESC("nextBillingDesc"),
    NAME_ASC("nameAsc"),
    AMOUNT_DESC("amountDesc"),
    CUSTOM("custom");

    companion object {
        fun fromStorageValue(rawValue: String?): BoardSortOption =
            entries.firstOrNull { it.storageValue == rawValue } ?: NEXT_BILLING_ASC
    }
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
            subscriptions = subscriptions,
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

    fun archive(ids: Set<UUID>) {
        viewModelScope.launch {
            ids.forEach { id ->
                repository.archive(id)
            }
        }
    }

    fun create(subscription: Subscription) {
        viewModelScope.launch {
            repository.create(subscription)
        }
    }

    fun update(subscription: Subscription) {
        viewModelScope.launch {
            repository.update(subscription.copy(updatedAt = Instant.now()))
        }
    }

    fun delete(subscription: Subscription) {
        viewModelScope.launch {
            repository.delete(subscription.id)
        }
    }

    fun delete(ids: Set<UUID>) {
        viewModelScope.launch {
            ids.forEach { id ->
                repository.delete(id)
            }
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

    fun markPaymentComplete(ids: Set<UUID>) {
        val subscriptions = uiState.value.subscriptions
        viewModelScope.launch {
            ids.mapNotNull { id -> subscriptions.firstOrNull { it.id == id } }
                .forEach { subscription ->
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
    }

    fun updateNextBillingDate(ids: Set<UUID>, date: Instant) {
        val subscriptions = uiState.value.subscriptions
        viewModelScope.launch {
            ids.mapNotNull { id -> subscriptions.firstOrNull { it.id == id } }
                .forEach { subscription ->
                    repository.update(
                        subscription.copy(
                            nextBillingDate = date,
                            updatedAt = Instant.now(),
                        ),
                    )
                }
        }
    }

    fun cancelPaymentComplete(subscription: Subscription) {
        viewModelScope.launch {
            val remainingHistory = subscription.paymentHistoryDates.sorted().dropLast(1)
            if (subscription.lastPaymentDate == null && remainingHistory.isEmpty()) {
                return@launch
            }
            repository.update(
                subscription.copy(
                    paymentHistoryDates = remainingHistory,
                    lastPaymentDate = remainingHistory.lastOrNull(),
                    nextBillingDate = BillingDateCalculator.rewind(subscription.nextBillingDate, subscription.billingCycle),
                    updatedAt = Instant.now(),
                ),
            )
        }
    }

    fun cancelPaymentComplete(ids: Set<UUID>) {
        val subscriptions = uiState.value.subscriptions
        viewModelScope.launch {
            ids.mapNotNull { id -> subscriptions.firstOrNull { it.id == id } }
                .forEach { subscription ->
                    val remainingHistory = subscription.paymentHistoryDates.sorted().dropLast(1)
                    if (subscription.lastPaymentDate == null && remainingHistory.isEmpty()) {
                        return@forEach
                    }
                    repository.update(
                        subscription.copy(
                            paymentHistoryDates = remainingHistory,
                            lastPaymentDate = remainingHistory.lastOrNull(),
                            nextBillingDate = BillingDateCalculator.rewind(subscription.nextBillingDate, subscription.billingCycle),
                            updatedAt = Instant.now(),
                        ),
                    )
                }
        }
    }

    fun setPinned(subscription: Subscription, isPinned: Boolean) {
        viewModelScope.launch {
            repository.update(
                subscription.copy(
                    isPinned = isPinned,
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
