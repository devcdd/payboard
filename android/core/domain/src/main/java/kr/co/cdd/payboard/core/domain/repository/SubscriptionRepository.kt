package kr.co.cdd.payboard.core.domain.repository

import kotlinx.coroutines.flow.Flow
import kr.co.cdd.payboard.core.domain.model.Subscription
import java.util.UUID

interface SubscriptionRepository {
    fun observeActive(): Flow<List<Subscription>>
    fun observeArchived(): Flow<List<Subscription>>

    suspend fun fetchAll(): List<Subscription>
    suspend fun replaceAll(subscriptions: List<Subscription>)
    suspend fun create(subscription: Subscription)
    suspend fun update(subscription: Subscription)
    suspend fun delete(id: UUID)
    suspend fun archive(id: UUID)
    suspend fun restore(id: UUID)
}
