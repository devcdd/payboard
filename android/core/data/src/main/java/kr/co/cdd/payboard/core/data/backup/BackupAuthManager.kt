package kr.co.cdd.payboard.core.data.backup

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.github.jan.supabase.auth.Auth
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.handleDeeplinks
import io.github.jan.supabase.auth.providers.Kakao
import io.github.jan.supabase.createSupabaseClient
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.intOrNull
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kr.co.cdd.payboard.core.domain.model.BillingCycle
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.model.SubscriptionCategory
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository
import java.io.IOException
import java.math.BigDecimal
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.time.Instant

enum class BackupAuthNotice {
    NOT_CONFIGURED,
    SIGN_IN_SUCCESS,
    SIGN_IN_FAILED,
    SIGN_OUT_SUCCESS,
    SIGN_OUT_FAILED,
    SIGN_IN_RESTORE_PROMPT,
    SIGN_IN_AUTO_BACKUP_DONE,
    SIGN_IN_RESTORE_SKIPPED,
    UPLOAD_SUCCESS,
    UPLOAD_FAILED,
    RESTORE_SUCCESS,
    RESTORE_FAILED,
    RESTORE_EMPTY,
    DELETE_ACCOUNT_SERVER_NOT_CONFIGURED,
    DELETE_ACCOUNT_SUCCESS,
    DELETE_ACCOUNT_FAILED,
}

data class BackupAuthState(
    val isConfigured: Boolean = false,
    val isSignedIn: Boolean = false,
    val accountIdentifier: String? = null,
    val latestBackupAt: Instant? = null,
    val notice: BackupAuthNotice? = null,
    val debugText: String? = null,
    val isBusy: Boolean = false,
    val isSyncInProgress: Boolean = false,
    val isAccountDeletionInProgress: Boolean = false,
    val isShowingRestorePromptAfterSignIn: Boolean = false,
)

class BackupAuthManager(
    context: Context,
    private val subscriptionRepository: SubscriptionRepository,
) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val config = loadConfiguration(appContext)
    private val accountDeletionServerUrl = normalizedMetaDataValue(appContext, "PAYBOARD_SERVER_URL")
    private val json = Json { ignoreUnknownKeys = true }
    private val supabase = config?.let { loadedConfig ->
        createSupabaseClient(
            supabaseUrl = loadedConfig.url,
            supabaseKey = loadedConfig.anonKey,
        ) {
            install(Auth) {
                host = DEEP_LINK_HOST
                scheme = DEEP_LINK_SCHEME
            }
        }
    }

    private val _state = MutableStateFlow(
        BackupAuthState(
            isConfigured = supabase != null,
            debugText = if (supabase == null) configurationDebugText(appContext, false) else null,
        ),
    )
    val state: StateFlow<BackupAuthState> = _state.asStateFlow()

    init {
        if (supabase != null) {
            refreshState()
        }
    }

    fun refreshState() {
        scope.launch {
            refreshBackupAuthState()
        }
    }

    fun clearNotice() {
        _state.value = _state.value.copy(notice = null)
    }

    suspend fun signInWithKakao() {
        val client = supabase ?: run {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.NOT_CONFIGURED,
                debugText = configurationDebugText(appContext, false),
            )
            return
        }
        _state.value = _state.value.copy(isBusy = true, debugText = null)
        runCatching {
            client.auth.signInWith(Kakao, redirectUrl = DEEP_LINK_REDIRECT_URL)
        }.onFailure { error ->
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.SIGN_IN_FAILED,
                debugText = describeBackupError(error, "sign_in"),
                isBusy = false,
            )
        }
    }

    suspend fun signOut() {
        val client = supabase ?: run {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.NOT_CONFIGURED,
                debugText = configurationDebugText(appContext, false),
            )
            return
        }
        _state.value = _state.value.copy(isBusy = true, debugText = null)
        runCatching {
            client.auth.signOut()
        }.onSuccess {
            _state.value = _state.value.copy(
                isSignedIn = false,
                accountIdentifier = null,
                latestBackupAt = null,
                notice = BackupAuthNotice.SIGN_OUT_SUCCESS,
                debugText = null,
                isBusy = false,
                isShowingRestorePromptAfterSignIn = false,
            )
        }.onFailure { error ->
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.SIGN_OUT_FAILED,
                debugText = describeBackupError(error, "sign_out"),
                isBusy = false,
            )
        }
    }

    suspend fun uploadBackup() {
        val client = supabase ?: run {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.NOT_CONFIGURED,
                debugText = configurationDebugText(appContext, false),
            )
            return
        }
        if (_state.value.isSyncInProgress || _state.value.isAccountDeletionInProgress) return

        _state.value = _state.value.copy(isSyncInProgress = true, debugText = null)
        try {
            val session = client.auth.currentSessionOrNull() ?: throw IOException("No active session")
            val subscriptions = subscriptionRepository.fetchAll()
            val timestamp = Instant.now()
            replaceRemoteBackup(
                accessToken = session.accessToken,
                userId = session.user?.id?.toString().orEmpty(),
                subscriptions = subscriptions,
                updatedAt = timestamp,
            )
            _state.value = _state.value.copy(
                latestBackupAt = timestamp,
                notice = BackupAuthNotice.UPLOAD_SUCCESS,
                debugText = null,
                isSyncInProgress = false,
            )
        } catch (error: Throwable) {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.UPLOAD_FAILED,
                debugText = describeBackupError(error, "upload"),
                isSyncInProgress = false,
            )
        }
    }

    suspend fun restoreLatestBackup() {
        val client = supabase ?: run {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.NOT_CONFIGURED,
                debugText = configurationDebugText(appContext, false),
            )
            return
        }
        if (_state.value.isSyncInProgress || _state.value.isAccountDeletionInProgress) return

        _state.value = _state.value.copy(
            isSyncInProgress = true,
            isShowingRestorePromptAfterSignIn = false,
            debugText = null,
        )
        try {
            val session = client.auth.currentSessionOrNull() ?: throw IOException("No active session")
            val userId = session.user?.id?.toString().orEmpty()
            val metadata = fetchLatestBackupMetadata(
                accessToken = session.accessToken,
                userId = userId,
            )
            if (metadata == null) {
                _state.value = _state.value.copy(
                    notice = BackupAuthNotice.RESTORE_EMPTY,
                    debugText = null,
                    isSyncInProgress = false,
                )
                return
            }

            val remoteSubscriptions = fetchRemoteSubscriptions(
                accessToken = session.accessToken,
                userId = userId,
            )
            val remotePaymentHistories = fetchRemotePaymentHistories(
                accessToken = session.accessToken,
                userId = userId,
            )
            val restoredSubscriptions = buildSubscriptions(
                remoteSubscriptions = remoteSubscriptions,
                paymentHistories = remotePaymentHistories,
            )
            subscriptionRepository.replaceAll(restoredSubscriptions)
            _state.value = _state.value.copy(
                latestBackupAt = metadata.updatedAt,
                notice = BackupAuthNotice.RESTORE_SUCCESS,
                debugText = null,
                isSyncInProgress = false,
            )
        } catch (error: Throwable) {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.RESTORE_FAILED,
                debugText = describeBackupError(error, "restore"),
                isSyncInProgress = false,
            )
        }
    }

    suspend fun deleteAccount() {
        val client = supabase ?: run {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.NOT_CONFIGURED,
                debugText = configurationDebugText(appContext, false),
            )
            return
        }
        val serverUrl = accountDeletionServerUrl ?: run {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.DELETE_ACCOUNT_SERVER_NOT_CONFIGURED,
                debugText = "PAYBOARD_SERVER_URL is missing",
            )
            return
        }
        if (_state.value.isSyncInProgress || _state.value.isAccountDeletionInProgress) return

        _state.value = _state.value.copy(isAccountDeletionInProgress = true, debugText = null)
        try {
            val session = client.auth.currentSessionOrNull() ?: throw IOException("No active session")
            deleteAccountFromServer(
                accessToken = session.accessToken,
                serverUrl = serverUrl,
            )
            runCatching { client.auth.signOut() }
            _state.value = _state.value.copy(
                isSignedIn = false,
                accountIdentifier = null,
                latestBackupAt = null,
                notice = BackupAuthNotice.DELETE_ACCOUNT_SUCCESS,
                debugText = null,
                isAccountDeletionInProgress = false,
                isShowingRestorePromptAfterSignIn = false,
            )
        } catch (error: Throwable) {
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.DELETE_ACCOUNT_FAILED,
                debugText = describeBackupError(error, "delete_account"),
                isAccountDeletionInProgress = false,
            )
        }
    }

    fun confirmRestoreAfterSignIn() {
        scope.launch {
            restoreLatestBackup()
        }
    }

    fun skipRestoreAfterSignIn() {
        _state.value = _state.value.copy(
            isShowingRestorePromptAfterSignIn = false,
            notice = BackupAuthNotice.SIGN_IN_RESTORE_SKIPPED,
        )
    }

    fun handleDeepLink(intent: Intent) {
        val client = supabase ?: return
        _state.value = _state.value.copy(isBusy = true)
        client.handleDeeplinks(
            intent = intent,
            onSessionSuccess = { session ->
                scope.launch {
                    val userId = session.user?.id?.toString().orEmpty()
                    val accountIdentifier = session.user?.email ?: userId
                    _state.value = _state.value.copy(
                        isBusy = false,
                        isSignedIn = true,
                        accountIdentifier = accountIdentifier,
                        notice = BackupAuthNotice.SIGN_IN_SUCCESS,
                        debugText = null,
                    )
                    bootstrapBackupAfterSignIn(
                        accessToken = session.accessToken,
                        userId = userId,
                        accountIdentifier = accountIdentifier,
                    )
                }
            },
            onError = { error ->
                _state.value = _state.value.copy(
                    isBusy = false,
                    notice = BackupAuthNotice.SIGN_IN_FAILED,
                    debugText = describeBackupError(error, "sign_in"),
                )
            },
        )
    }

    private suspend fun refreshBackupAuthState() {
        val client = supabase ?: run {
            _state.value = _state.value.copy(
                isConfigured = false,
                isSignedIn = false,
                accountIdentifier = null,
                latestBackupAt = null,
                debugText = configurationDebugText(appContext, false),
                isBusy = false,
            )
            return
        }
        _state.value = _state.value.copy(isBusy = true)
        try {
            val session = client.auth.currentSessionOrNull() ?: throw IOException("No active session")
            val latestBackupAt = fetchLatestBackupMetadata(
                accessToken = session.accessToken,
                userId = session.user?.id?.toString().orEmpty(),
            )?.updatedAt
            _state.value = _state.value.copy(
                isConfigured = true,
                isSignedIn = true,
                accountIdentifier = session.user?.email ?: session.user?.id?.toString(),
                latestBackupAt = latestBackupAt,
                debugText = null,
                isBusy = false,
            )
        } catch (_: Throwable) {
            _state.value = _state.value.copy(
                isConfigured = true,
                isSignedIn = false,
                accountIdentifier = null,
                latestBackupAt = null,
                debugText = null,
                isBusy = false,
            )
        }
    }

    private suspend fun bootstrapBackupAfterSignIn(
        accessToken: String,
        userId: String,
        accountIdentifier: String,
    ) {
        try {
            val metadata = fetchLatestBackupMetadata(
                accessToken = accessToken,
                userId = userId,
            )
            if (metadata != null) {
                _state.value = _state.value.copy(
                    isSignedIn = true,
                    accountIdentifier = accountIdentifier,
                    latestBackupAt = metadata.updatedAt,
                    notice = BackupAuthNotice.SIGN_IN_RESTORE_PROMPT,
                    isShowingRestorePromptAfterSignIn = true,
                    debugText = null,
                )
            } else {
                val subscriptions = subscriptionRepository.fetchAll()
                val timestamp = Instant.now()
                replaceRemoteBackup(
                    accessToken = accessToken,
                    userId = userId,
                    subscriptions = subscriptions,
                    updatedAt = timestamp,
                )
                _state.value = _state.value.copy(
                    isSignedIn = true,
                    accountIdentifier = accountIdentifier,
                    latestBackupAt = timestamp,
                    notice = BackupAuthNotice.SIGN_IN_AUTO_BACKUP_DONE,
                    isShowingRestorePromptAfterSignIn = false,
                    debugText = null,
                )
            }
        } catch (error: Throwable) {
            _state.value = _state.value.copy(
                debugText = describeBackupError(error, "post_sign_in_bootstrap"),
                isShowingRestorePromptAfterSignIn = false,
            )
        }
    }

    private suspend fun fetchLatestBackupMetadata(
        accessToken: String,
        userId: String,
    ): BackupMetadata? {
        val payload = executeRestRequest(
            method = "GET",
            path = LATEST_BACKUPS_TABLE,
            accessToken = accessToken,
            query = listOf(
                "select" to "user_id,item_count,created_at,updated_at",
                "user_id" to "eq.$userId",
                "limit" to "1",
            ),
        )
        val rows = payload.asJsonArray()
        return rows.firstOrNull()?.jsonObject?.toBackupMetadata()
    }

    private suspend fun fetchRemoteSubscriptions(
        accessToken: String,
        userId: String,
    ): List<RemoteSubscriptionItem> {
        val payload = executeRestRequest(
            method = "GET",
            path = BACKUP_ITEMS_TABLE,
            accessToken = accessToken,
            query = listOf(
                "select" to """
                    id,
                    user_id,
                    name,
                    category,
                    amount,
                    is_amount_undecided,
                    currency_code,
                    billing_cycle_kind,
                    billing_cycle_days,
                    next_billing_date,
                    last_payment_date,
                    icon_key,
                    icon_color_key,
                    custom_category_name,
                    notifications_enabled,
                    is_auto_pay_enabled,
                    is_pinned,
                    is_active,
                    memo,
                    sort_order,
                    created_at,
                    updated_at
                """.trimIndent().replace("\n", ""),
                "user_id" to "eq.$userId",
                "order" to "sort_order.asc,created_at.asc",
            ),
        )
        return payload.asJsonArray().map { it.jsonObject.toRemoteSubscriptionItem() }
    }

    private suspend fun fetchRemotePaymentHistories(
        accessToken: String,
        userId: String,
    ): List<RemotePaymentHistory> {
        val payload = executeRestRequest(
            method = "GET",
            path = PAYMENT_HISTORIES_TABLE,
            accessToken = accessToken,
            query = listOf(
                "select" to """
                    user_id,
                    subscription_id,
                    paid_at,
                    scheduled_date,
                    amount_snapshot,
                    currency_code,
                    is_auto_pay,
                    status,
                    created_at,
                    updated_at
                """.trimIndent().replace("\n", ""),
                "user_id" to "eq.$userId",
                "status" to "eq.paid",
            ),
        )
        return payload.asJsonArray().map { it.jsonObject.toRemotePaymentHistory() }
    }

    private suspend fun replaceRemoteBackup(
        accessToken: String,
        userId: String,
        subscriptions: List<Subscription>,
        updatedAt: Instant,
    ) {
        deleteRemoteBackupTables(accessToken = accessToken, userId = userId)

        if (subscriptions.isNotEmpty()) {
            executeRestRequest(
                method = "POST",
                path = BACKUP_ITEMS_TABLE,
                accessToken = accessToken,
                body = buildBackupItemsPayload(userId, subscriptions),
                prefer = "return=minimal",
            )
        }

        val paymentRowsPayload = buildPaymentHistoriesPayload(userId, subscriptions)
        if (paymentRowsPayload != "[]") {
            executeRestRequest(
                method = "POST",
                path = PAYMENT_HISTORIES_TABLE,
                accessToken = accessToken,
                body = paymentRowsPayload,
                prefer = "return=minimal",
            )
        }

        executeRestRequest(
            method = "POST",
            path = LATEST_BACKUPS_TABLE,
            accessToken = accessToken,
            query = listOf("on_conflict" to "user_id"),
            body = buildBackupMetadataPayload(
                userId = userId,
                itemCount = subscriptions.size,
                updatedAt = updatedAt,
            ),
            prefer = "resolution=merge-duplicates,return=minimal",
        )
    }

    private suspend fun deleteRemoteBackupTables(
        accessToken: String,
        userId: String,
    ) {
        executeRestRequest(
            method = "DELETE",
            path = PAYMENT_HISTORIES_TABLE,
            accessToken = accessToken,
            query = listOf("user_id" to "eq.$userId"),
        )
        executeRestRequest(
            method = "DELETE",
            path = BACKUP_ITEMS_TABLE,
            accessToken = accessToken,
            query = listOf("user_id" to "eq.$userId"),
        )
    }

    private suspend fun deleteAccountFromServer(
        accessToken: String,
        serverUrl: String,
    ) {
        val payload = buildJsonObject {
            put("reason", JsonPrimitive("user_requested"))
        }.toString()
        val endpoint = Uri.parse(serverUrl)
            .buildUpon()
            .appendPath("v1")
            .appendPath("account")
            .appendPath("delete")
            .build()
            .toString()

        executeHttpRequest(
            url = URL(endpoint),
            method = "POST",
            accessToken = accessToken,
            anonKey = config?.anonKey,
            body = payload,
        )
    }

    private suspend fun executeRestRequest(
        method: String,
        path: String,
        accessToken: String,
        query: List<Pair<String, String>> = emptyList(),
        body: String? = null,
        prefer: String? = null,
    ): String {
        val loadedConfig = checkNotNull(config)
        val baseUrl = Uri.parse(loadedConfig.url)
            .buildUpon()
            .appendPath("rest")
            .appendPath("v1")
            .appendPath(path)
            .build()
            .toString()
        val uriBuilder = Uri.parse(baseUrl).buildUpon()
        query.forEach { (key, value) -> uriBuilder.appendQueryParameter(key, value) }
        return executeHttpRequest(
            url = URL(uriBuilder.build().toString()),
            method = method,
            accessToken = accessToken,
            anonKey = loadedConfig.anonKey,
            body = body,
            prefer = prefer,
        )
    }

    private suspend fun executeHttpRequest(
        url: URL,
        method: String,
        accessToken: String,
        anonKey: String?,
        body: String? = null,
        prefer: String? = null,
    ): String = withContext(Dispatchers.IO) {
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 15_000
            setRequestProperty("Accept", "application/json")
            if (!anonKey.isNullOrBlank()) {
                setRequestProperty("apikey", anonKey)
            }
            setRequestProperty("Authorization", "Bearer $accessToken")
            if (prefer != null) {
                setRequestProperty("Prefer", prefer)
            }
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
        }
        try {
            if (body != null) {
                connection.outputStream.use { output ->
                    output.write(body.toByteArray(StandardCharsets.UTF_8))
                }
            }
            val responseCode = connection.responseCode
            val payload = (if (responseCode in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()
                ?.use { it.readText() }
                .orEmpty()
            if (responseCode !in 200..299) {
                val message = extractServerErrorMessage(payload).ifBlank { "HTTP $responseCode" }
                throw IOException(message)
            }
            payload
        } finally {
            connection.disconnect()
        }
    }

    private fun buildBackupMetadataPayload(
        userId: String,
        itemCount: Int,
        updatedAt: Instant,
    ): String = buildJsonObject {
        put("user_id", JsonPrimitive(userId))
        put("backup_version", JsonPrimitive(2))
        put("item_count", JsonPrimitive(itemCount))
        put("device_id", JsonNull)
        put("app_version", JsonNull)
        put("updated_at", JsonPrimitive(updatedAt.toString()))
    }.toString()

    private fun buildBackupItemsPayload(
        userId: String,
        subscriptions: List<Subscription>,
    ): String = buildJsonArray {
        subscriptions.forEachIndexed { index, subscription ->
            add(buildJsonObject {
                put("id", JsonPrimitive(subscription.id.toString()))
                put("user_id", JsonPrimitive(userId))
                put("name", JsonPrimitive(subscription.name))
                put("category", JsonPrimitive(subscription.category.name.lowercase()))
                put("amount", JsonPrimitive(subscription.amount))
                put("is_amount_undecided", JsonPrimitive(subscription.isAmountUndecided))
                put("currency_code", JsonPrimitive(subscription.currencyCode))
                val (kind, days) = flattenBillingCycle(subscription.billingCycle)
                put("billing_cycle_kind", JsonPrimitive(kind))
                put("billing_cycle_days", JsonPrimitive(days))
                put("next_billing_date", JsonPrimitive(subscription.nextBillingDate.toString()))
                if (subscription.lastPaymentDate != null) {
                    put("last_payment_date", JsonPrimitive(subscription.lastPaymentDate.toString()))
                } else {
                    put("last_payment_date", JsonNull)
                }
                put("icon_key", JsonPrimitive(subscription.iconKey))
                put("icon_color_key", JsonPrimitive(subscription.iconColorKey))
                if (subscription.customCategoryName != null) {
                    put("custom_category_name", JsonPrimitive(subscription.customCategoryName))
                } else {
                    put("custom_category_name", JsonNull)
                }
                put("notifications_enabled", JsonPrimitive(subscription.notificationsEnabled))
                put("is_auto_pay_enabled", JsonPrimitive(subscription.isAutoPayEnabled))
                put("is_pinned", JsonPrimitive(subscription.isPinned))
                put("is_active", JsonPrimitive(subscription.isActive))
                if (subscription.memo != null) {
                    put("memo", JsonPrimitive(subscription.memo))
                } else {
                    put("memo", JsonNull)
                }
                put("sort_order", JsonPrimitive(index))
                put("created_at", JsonPrimitive(subscription.createdAt.toString()))
                put("updated_at", JsonPrimitive(subscription.updatedAt.toString()))
            })
        }
    }.toString()

    private fun buildPaymentHistoriesPayload(
        userId: String,
        subscriptions: List<Subscription>,
    ): String = buildJsonArray {
        subscriptions.forEach { subscription ->
            val paidDates = (subscription.paymentHistoryDates + listOfNotNull(subscription.lastPaymentDate))
                .distinct()
                .sorted()
            paidDates.forEach { paidAt ->
                add(buildJsonObject {
                    put("user_id", JsonPrimitive(userId))
                    put("subscription_id", JsonPrimitive(subscription.id.toString()))
                    put("paid_at", JsonPrimitive(paidAt.toString()))
                    put("scheduled_date", JsonPrimitive(paidAt.toString()))
                    put("amount_snapshot", JsonPrimitive(subscription.amount))
                    put("currency_code", JsonPrimitive(subscription.currencyCode))
                    put("is_auto_pay", JsonPrimitive(subscription.isAutoPayEnabled))
                    put("status", JsonPrimitive("paid"))
                    put("created_at", JsonPrimitive(subscription.createdAt.toString()))
                    put("updated_at", JsonPrimitive(subscription.updatedAt.toString()))
                })
            }
        }
    }.toString()

    private fun buildSubscriptions(
        remoteSubscriptions: List<RemoteSubscriptionItem>,
        paymentHistories: List<RemotePaymentHistory>,
    ): List<Subscription> {
        val paymentHistoryMap = paymentHistories.groupBy(RemotePaymentHistory::subscriptionId)
        return remoteSubscriptions
            .sortedWith(compareBy<RemoteSubscriptionItem> { it.sortOrder }.thenBy { it.createdAt })
            .map { row ->
                val paidDates = paymentHistoryMap[row.id]
                    .orEmpty()
                    .map(RemotePaymentHistory::paidAt)
                    .sorted()
                row.toSubscription(paidDates)
            }
    }

    private fun flattenBillingCycle(cycle: BillingCycle): Pair<String, Int> = when (cycle) {
        BillingCycle.Monthly -> "monthly" to 30
        BillingCycle.Yearly -> "yearly" to 365
        is BillingCycle.CustomDays -> "custom_days" to cycle.days.coerceAtLeast(1)
    }

    private fun expandBillingCycle(kind: String, days: Int?): BillingCycle = when (kind) {
        "monthly" -> BillingCycle.Monthly
        "yearly" -> BillingCycle.Yearly
        "custom_days" -> BillingCycle.CustomDays((days ?: 30).coerceAtLeast(1))
        else -> BillingCycle.Monthly
    }

    private fun JsonObject.toBackupMetadata(): BackupMetadata = BackupMetadata(
        itemCount = int("item_count"),
        updatedAt = Instant.parse(string("updated_at")),
    )

    private fun JsonObject.toRemoteSubscriptionItem(): RemoteSubscriptionItem = RemoteSubscriptionItem(
        id = string("id"),
        name = string("name"),
        category = string("category"),
        amount = BigDecimal(string("amount")),
        isAmountUndecided = boolean("is_amount_undecided"),
        currencyCode = string("currency_code"),
        billingCycleKind = string("billing_cycle_kind"),
        billingCycleDays = optionalInt("billing_cycle_days"),
        nextBillingDate = Instant.parse(string("next_billing_date")),
        lastPaymentDate = optionalString("last_payment_date")?.let(Instant::parse),
        iconKey = string("icon_key"),
        iconColorKey = string("icon_color_key"),
        customCategoryName = optionalString("custom_category_name"),
        notificationsEnabled = boolean("notifications_enabled"),
        isAutoPayEnabled = boolean("is_auto_pay_enabled"),
        isPinned = boolean("is_pinned"),
        isActive = boolean("is_active"),
        memo = optionalString("memo"),
        sortOrder = int("sort_order"),
        createdAt = Instant.parse(string("created_at")),
        updatedAt = Instant.parse(string("updated_at")),
    )

    private fun JsonObject.toRemotePaymentHistory(): RemotePaymentHistory = RemotePaymentHistory(
        subscriptionId = string("subscription_id"),
        paidAt = Instant.parse(string("paid_at")),
    )

    private fun RemoteSubscriptionItem.toSubscription(paymentHistoryDates: List<Instant>): Subscription {
        val category = runCatching { SubscriptionCategory.valueOf(category.uppercase()) }
            .getOrDefault(SubscriptionCategory.OTHER)
        return Subscription(
            id = java.util.UUID.fromString(id),
            name = name,
            category = category,
            amount = amount,
            isAmountUndecided = isAmountUndecided,
            currencyCode = currencyCode,
            billingCycle = expandBillingCycle(billingCycleKind, billingCycleDays),
            nextBillingDate = nextBillingDate,
            lastPaymentDate = paymentHistoryDates.maxOrNull() ?: lastPaymentDate,
            paymentHistoryDates = paymentHistoryDates,
            iconKey = iconKey,
            iconColorKey = iconColorKey,
            customCategoryName = customCategoryName,
            notificationsEnabled = notificationsEnabled,
            isAutoPayEnabled = isAutoPayEnabled,
            isPinned = isPinned,
            isActive = isActive,
            memo = memo,
            createdAt = createdAt,
            updatedAt = updatedAt,
        )
    }

    private fun JsonObject.string(key: String): String =
        get(key)?.jsonPrimitive?.contentOrNull ?: throw IOException("Missing field: $key")

    private fun JsonObject.optionalString(key: String): String? = get(key)?.let { element ->
        if (element is JsonNull) null else element.jsonPrimitive.contentOrNull
    }

    private fun JsonObject.boolean(key: String): Boolean =
        get(key)?.jsonPrimitive?.booleanOrNull ?: false

    private fun JsonObject.int(key: String): Int =
        get(key)?.jsonPrimitive?.intOrNull ?: throw IOException("Missing field: $key")

    private fun JsonObject.optionalInt(key: String): Int? =
        get(key)?.jsonPrimitive?.intOrNull

    private fun String.asJsonArray(): JsonArray =
        if (isBlank()) JsonArray(emptyList()) else json.parseToJsonElement(this).jsonArray

    private fun extractServerErrorMessage(payload: String): String {
        if (payload.isBlank()) return ""
        return runCatching {
            val jsonObject = json.parseToJsonElement(payload).jsonObject
            jsonObject["error"]?.jsonPrimitive?.contentOrNull
                ?: jsonObject["message"]?.jsonPrimitive?.contentOrNull
                ?: payload
        }.getOrDefault(payload)
    }

    private fun describeBackupError(error: Throwable, operation: String): String {
        return "$operation: ${error.message ?: error::class.java.simpleName}"
    }

    private data class Configuration(
        val url: String,
        val anonKey: String,
    )

    private data class BackupMetadata(
        val itemCount: Int,
        val updatedAt: Instant,
    )

    private data class RemoteSubscriptionItem(
        val id: String,
        val name: String,
        val category: String,
        val amount: BigDecimal,
        val isAmountUndecided: Boolean,
        val currencyCode: String,
        val billingCycleKind: String,
        val billingCycleDays: Int?,
        val nextBillingDate: Instant,
        val lastPaymentDate: Instant?,
        val iconKey: String,
        val iconColorKey: String,
        val customCategoryName: String?,
        val notificationsEnabled: Boolean,
        val isAutoPayEnabled: Boolean,
        val isPinned: Boolean,
        val isActive: Boolean,
        val memo: String?,
        val sortOrder: Int,
        val createdAt: Instant,
        val updatedAt: Instant,
    )

    private data class RemotePaymentHistory(
        val subscriptionId: String,
        val paidAt: Instant,
    )

    companion object {
        const val DEEP_LINK_SCHEME = "payboard"
        const val DEEP_LINK_HOST = "auth"
        const val DEEP_LINK_PATH = "/callback"
        const val DEEP_LINK_REDIRECT_URL = "$DEEP_LINK_SCHEME://$DEEP_LINK_HOST$DEEP_LINK_PATH"

        private const val LATEST_BACKUPS_TABLE = "subscription_latest_backups"
        private const val BACKUP_ITEMS_TABLE = "subscription_items"
        private const val PAYMENT_HISTORIES_TABLE = "subscription_payment_histories"

        private fun loadConfiguration(context: Context): Configuration? {
            val url = normalizedMetaDataValue(context, "SUPABASE_URL")
            val anonKey = normalizedMetaDataValue(context, "SUPABASE_ANON_KEY")
            if (url == null || anonKey == null) return null
            return Configuration(url = url, anonKey = anonKey)
        }

        private fun configurationDebugText(
            context: Context,
            isConfigured: Boolean,
        ): String {
            val url = normalizedMetaDataValue(context, "SUPABASE_URL") ?: "<nil>"
            val key = normalizedMetaDataValue(context, "SUPABASE_ANON_KEY")?.let(::maskSecret) ?: "<nil>"
            val serverUrl = normalizedMetaDataValue(context, "PAYBOARD_SERVER_URL") ?: "<nil>"
            return listOf(
                "SUPABASE_URL: $url",
                "SUPABASE_ANON_KEY: $key",
                "PAYBOARD_SERVER_URL: $serverUrl",
                "isBackupConfigured: $isConfigured",
            ).joinToString(separator = "\n")
        }

        private fun normalizedMetaDataValue(context: Context, key: String): String? {
            val applicationInfo = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
            val rawValue = applicationInfo.metaData?.getString(key) ?: return null
            val trimmed = rawValue.trim()
            return trimmed.takeIf { it.isNotEmpty() && !it.startsWith("$") }
        }

        private fun maskSecret(value: String): String {
            return if (value.length <= 8) {
                "*".repeat(value.length)
            } else {
                "${value.take(6)}***${value.takeLast(4)}"
            }
        }
    }
}
