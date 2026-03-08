package kr.co.cdd.payboard.core.data.repository

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import kr.co.cdd.payboard.core.data.local.LocalJsonStore
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository
import java.time.Instant
import java.util.UUID

class FileSubscriptionRepository(
    context: Context,
) : SubscriptionRepository {
    private val store = LocalJsonStore(context.applicationContext)
    private val allSubscriptions = MutableStateFlow(store.load())

    override fun observeActive(): Flow<List<Subscription>> =
        allSubscriptions.map { subscriptions ->
            subscriptions
                .filter(Subscription::isActive)
                .sortedBy(Subscription::nextBillingDate)
        }

    override fun observeArchived(): Flow<List<Subscription>> =
        allSubscriptions.map { subscriptions ->
            subscriptions
                .filterNot(Subscription::isActive)
                .sortedByDescending(Subscription::updatedAt)
        }

    override suspend fun fetchAll(): List<Subscription> = withContext(Dispatchers.IO) {
        allSubscriptions.value.toList()
    }

    override suspend fun replaceAll(subscriptions: List<Subscription>) {
        withContext(Dispatchers.IO) {
            subscriptions.forEach(Subscription::validate)
            store.save(subscriptions)
            allSubscriptions.value = subscriptions
        }
    }

    override suspend fun create(subscription: Subscription) {
        persist {
            subscription.validate()
            add(subscription)
        }
    }

    override suspend fun update(subscription: Subscription) {
        persist {
            subscription.validate()
            replaceAll { current ->
                if (current.id == subscription.id) subscription else current
            }
        }
    }

    override suspend fun delete(id: UUID) {
        persist {
            removeAll { it.id == id }
        }
    }

    override suspend fun archive(id: UUID) {
        persist {
            replaceAll { current ->
                if (current.id == id) current.copy(isActive = false, updatedAt = Instant.now()) else current
            }
        }
    }

    override suspend fun restore(id: UUID) {
        persist {
            replaceAll { current ->
                if (current.id == id) current.copy(isActive = true, updatedAt = Instant.now()) else current
            }
        }
    }

    private suspend fun persist(transform: MutableList<Subscription>.() -> Unit) {
        withContext(Dispatchers.IO) {
            val next = allSubscriptions.value.toMutableList().apply(transform)
            store.save(next)
            allSubscriptions.value = next
        }
    }
}
