package kr.co.cdd.payboard.feature.board

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kr.co.cdd.payboard.core.data.backup.BackupAuthManager
import kr.co.cdd.payboard.core.data.notifications.SubscriptionReminderScheduler
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository
import kr.co.cdd.payboard.core.domain.repository.UserPreferencesRepository
import kr.co.cdd.payboard.core.domain.usecase.BillingDateCalculator
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
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
    val errorMessage: String? = null,
)

class BoardViewModel(
    private val repository: SubscriptionRepository,
    private val backupAuthManager: BackupAuthManager,
    private val userPreferencesRepository: UserPreferencesRepository,
    private val reminderScheduler: SubscriptionReminderScheduler,
) : ViewModel() {
    private val searchQuery = MutableStateFlow("")
    private val selectedFilter = MutableStateFlow(BoardFilter.ALL)
    private val errorMessage = MutableStateFlow<String?>(null)
    private var hasBootstrappedOnAppStart = false

    val uiState: StateFlow<BoardUiState> = combine(
        repository.observeActive(),
        searchQuery,
        selectedFilter,
        errorMessage,
    ) { subscriptions, query, filter, currentError ->
        BoardUiState(
            subscriptions = subscriptions,
            searchQuery = query,
            selectedFilter = filter,
            errorMessage = currentError,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = BoardUiState(),
    )

    fun bootstrapOnAppStart() {
        if (hasBootstrappedOnAppStart) return
        hasBootstrappedOnAppStart = true

        viewModelScope.launch {
            runBoardAction {
                val preferences = userPreferencesRepository.preferences.first()
                val today = LocalDate.now(ZoneId.systemDefault())
                val allSubscriptions = repository.fetchAll()
                val overdueAutoPay = allSubscriptions.filter { subscription ->
                    subscription.isActive &&
                        subscription.isAutoPayEnabled &&
                        subscription.nextBillingDate.toLocalDate() <= today
                }

                overdueAutoPay.forEach { subscription ->
                    repository.update(completedSubscription(subscription, Instant.now()))
                }

                val activeSubscriptions = repository.fetchAll().filter(Subscription::isActive)
                reminderScheduler.syncAll(activeSubscriptions, preferences)
                if (overdueAutoPay.isNotEmpty()) {
                    backupAuthManager.autoBackupAfterSubscriptionUpsert()
                }
            }
        }
    }

    fun clearError() {
        errorMessage.value = null
    }

    fun updateSearchQuery(query: String) {
        searchQuery.value = query
    }

    fun updateFilter(filter: BoardFilter) {
        selectedFilter.value = filter
    }

    fun archive(subscription: Subscription) {
        viewModelScope.launch {
            runBoardAction {
                repository.archive(subscription.id)
                reminderScheduler.cancelSubscription(subscription.id)
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun archive(ids: Set<UUID>) {
        if (ids.isEmpty()) return
        viewModelScope.launch {
            runBoardAction {
                ids.forEach { id ->
                    repository.archive(id)
                    reminderScheduler.cancelSubscription(id)
                }
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun create(subscription: Subscription) {
        viewModelScope.launch {
            runBoardAction {
                repository.create(subscription)
                reminderScheduler.syncSubscription(subscription, userPreferencesRepository.preferences.first())
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun update(subscription: Subscription) {
        viewModelScope.launch {
            runBoardAction {
                val updated = subscription.copy(updatedAt = Instant.now())
                repository.update(updated)
                reminderScheduler.syncSubscription(updated, userPreferencesRepository.preferences.first())
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun delete(subscription: Subscription) {
        viewModelScope.launch {
            runBoardAction {
                repository.delete(subscription.id)
                reminderScheduler.cancelSubscription(subscription.id)
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun delete(ids: Set<UUID>) {
        if (ids.isEmpty()) return
        viewModelScope.launch {
            runBoardAction {
                ids.forEach { id ->
                    repository.delete(id)
                    reminderScheduler.cancelSubscription(id)
                }
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun markPaymentComplete(subscription: Subscription) {
        viewModelScope.launch {
            runBoardAction {
                val completed = completedSubscription(subscription, Instant.now())
                repository.update(completed)
                reminderScheduler.syncSubscription(completed, userPreferencesRepository.preferences.first())
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun markPaymentComplete(ids: Set<UUID>) {
        if (ids.isEmpty()) return
        val subscriptions = uiState.value.subscriptions
        viewModelScope.launch {
            runBoardAction {
                ids.mapNotNull { id -> subscriptions.firstOrNull { it.id == id } }
                    .forEach { subscription ->
                        repository.update(completedSubscription(subscription, Instant.now()))
                    }
                reminderScheduler.syncAll(
                    repository.fetchAll().filter(Subscription::isActive),
                    userPreferencesRepository.preferences.first(),
                )
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun updateNextBillingDate(ids: Set<UUID>, date: Instant) {
        if (ids.isEmpty()) return
        val subscriptions = uiState.value.subscriptions
        viewModelScope.launch {
            runBoardAction {
                ids.mapNotNull { id -> subscriptions.firstOrNull { it.id == id } }
                    .forEach { subscription ->
                        repository.update(
                            subscription.copy(
                                nextBillingDate = date,
                                updatedAt = Instant.now(),
                            ),
                        )
                    }
                reminderScheduler.syncAll(
                    repository.fetchAll().filter(Subscription::isActive),
                    userPreferencesRepository.preferences.first(),
                )
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun cancelPaymentComplete(subscription: Subscription) {
        viewModelScope.launch {
            runBoardAction {
                val canceled = canceledSubscription(subscription) ?: return@runBoardAction
                repository.update(canceled)
                reminderScheduler.syncSubscription(canceled, userPreferencesRepository.preferences.first())
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun cancelPaymentComplete(ids: Set<UUID>) {
        if (ids.isEmpty()) return
        val subscriptions = uiState.value.subscriptions
        viewModelScope.launch {
            runBoardAction {
                ids.mapNotNull { id -> subscriptions.firstOrNull { it.id == id } }
                    .mapNotNull(::canceledSubscription)
                    .forEach { updated ->
                        repository.update(updated)
                    }
                reminderScheduler.syncAll(
                    repository.fetchAll().filter(Subscription::isActive),
                    userPreferencesRepository.preferences.first(),
                )
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    fun setPinned(subscription: Subscription, isPinned: Boolean) {
        viewModelScope.launch {
            runBoardAction {
                repository.update(
                    subscription.copy(
                        isPinned = isPinned,
                        updatedAt = Instant.now(),
                    ),
                )
                backupAuthManager.autoBackupAfterSubscriptionUpsert()
            }
        }
    }

    private suspend fun runBoardAction(action: suspend () -> Unit) {
        errorMessage.value = null
        runCatching { action() }
            .onFailure { throwable ->
                errorMessage.value = throwable.message
            }
    }

    private fun completedSubscription(
        subscription: Subscription,
        paidAt: Instant,
    ): Subscription = subscription.copy(
        lastPaymentDate = paidAt,
        paymentHistoryDates = subscription.paymentHistoryDates + paidAt,
        nextBillingDate = BillingDateCalculator.advance(subscription.nextBillingDate, subscription.billingCycle),
        updatedAt = paidAt,
    )

    private fun canceledSubscription(subscription: Subscription): Subscription? {
        val remainingHistory = subscription.paymentHistoryDates.sorted().dropLast(1)
        if (subscription.lastPaymentDate == null && remainingHistory.isEmpty()) {
            return null
        }
        return subscription.copy(
            paymentHistoryDates = remainingHistory,
            lastPaymentDate = remainingHistory.lastOrNull(),
            nextBillingDate = BillingDateCalculator.rewind(subscription.nextBillingDate, subscription.billingCycle),
            updatedAt = Instant.now(),
        )
    }

    private fun Instant.toLocalDate(): LocalDate =
        atZone(ZoneId.systemDefault()).toLocalDate()

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
                    return BoardViewModel(
                        repository = repository,
                        backupAuthManager = backupAuthManager,
                        userPreferencesRepository = userPreferencesRepository,
                        reminderScheduler = reminderScheduler,
                    ) as T
                }
            }
    }
}
