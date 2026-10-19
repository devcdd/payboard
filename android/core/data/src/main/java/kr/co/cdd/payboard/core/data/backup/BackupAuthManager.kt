package kr.co.cdd.payboard.core.data.backup

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Base64
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
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
import kotlinx.serialization.json.longOrNull
import kr.co.cdd.payboard.core.data.notifications.SubscriptionReminderScheduler
import kr.co.cdd.payboard.core.domain.model.BillingCycle
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.model.SubscriptionCategory
import kr.co.cdd.payboard.core.domain.repository.SubscriptionRepository
import kr.co.cdd.payboard.core.domain.repository.UserPreferencesRepository
import java.io.FileNotFoundException
import java.io.IOException
import java.math.BigDecimal
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Instant
import java.time.OffsetDateTime

enum class BackupAuthNotice {
    NOT_CONFIGURED,
    SIGN_IN_SUCCESS,
    SIGN_IN_FAILED,
    SIGN_OUT_SUCCESS,
    SIGN_IN_RESTORE_PROMPT,
    SIGN_IN_AUTO_BACKUP_DONE,
    SIGN_IN_RESTORE_SKIPPED,
    UPLOAD_SUCCESS,
    UPLOAD_FAILED,
    RESTORE_SUCCESS,
    RESTORE_FAILED,
    RESTORE_EMPTY,
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
    private val userPreferencesRepository: UserPreferencesRepository,
    private val reminderScheduler: SubscriptionReminderScheduler,
) {
    private val appContext = context.applicationContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val serverUrl = normalizedMetaDataValue(appContext, "PAYBOARD_SERVER_URL")
    private val json = Json { ignoreUnknownKeys = true }
    private val prefs = appContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    // refresh token 이 1회용(rotation)이라 동시에 갱신하면 하나가 무효화되므로 직렬화함
    private val sessionMutex = Mutex()

    private val _state = MutableStateFlow(
        BackupAuthState(
            isConfigured = serverUrl != null,
            debugText = if (serverUrl == null) configurationDebugText(appContext, false) else null,
        ),
    )
    val state: StateFlow<BackupAuthState> = _state.asStateFlow()
    @Volatile
    private var isHandlingAuthCallback = false
    private var lastUploadRequestedAt: Instant? = null

    init {
        if (serverUrl != null) {
            refreshState()
        }
    }

    fun refreshState() {
        if (isHandlingAuthCallback) return
        scope.launch {
            refreshBackupAuthState()
        }
    }

    fun clearNotice() {
        _state.value = _state.value.copy(notice = null)
    }

    suspend fun signInWithKakao() {
        val baseUrl = serverUrl ?: run {
            notifyNotConfigured()
            return
        }
        _state.value = _state.value.copy(isBusy = true, debugText = null)
        runCatching {
            val verifier = base64Url(ByteArray(32).also(SecureRandom()::nextBytes))
            val challenge = base64Url(MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(StandardCharsets.US_ASCII)))
            // 브라우저를 다녀오는 사이 프로세스가 죽을 수 있어 verifier 를 메모리가 아닌 prefs 에 둠
            prefs.edit().putString(KEY_CODE_VERIFIER, verifier).apply()
            val startUri = Uri.parse(baseUrl).buildUpon()
                .appendEncodedPath("v1/auth/kakao/start")
                .appendQueryParameter("redirect_to", DEEP_LINK_REDIRECT_URL)
                .appendQueryParameter("code_challenge", challenge)
                .build()
            appContext.startActivity(
                Intent(Intent.ACTION_VIEW, startUri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }.onFailure { error ->
            _state.value = _state.value.copy(
                notice = BackupAuthNotice.SIGN_IN_FAILED,
                debugText = describeBackupError(error, "sign_in"),
                isBusy = false,
            )
        }
    }

    suspend fun signOut() {
        if (serverUrl == null) {
            notifyNotConfigured()
            return
        }
        _state.value = _state.value.copy(isBusy = true, debugText = null)
        // 서버 폐기가 실패해도 로컬 세션은 지워야 로그아웃이 보장됨
        loadSession()?.let { session ->
            runCatching {
                executeHttpRequest(
                    path = "v1/auth/signout",
                    method = "POST",
                    body = buildJsonObject { put("refresh_token", JsonPrimitive(session.refreshToken)) }.toString(),
                )
            }
        }
        clearSession()
        _state.value = _state.value.copy(
            isSignedIn = false,
            accountIdentifier = null,
            latestBackupAt = null,
            notice = BackupAuthNotice.SIGN_OUT_SUCCESS,
            debugText = null,
            isBusy = false,
            isShowingRestorePromptAfterSignIn = false,
        )
        lastUploadRequestedAt = null
    }

    suspend fun uploadBackup() {
        uploadBackup(showResultNotice = true)
    }

    suspend fun autoBackupAfterSubscriptionUpsert() {
        uploadBackup(showResultNotice = false)
    }

    private suspend fun uploadBackup(showResultNotice: Boolean) {
        val now = Instant.now()
        val lastRequestedAt = lastUploadRequestedAt
        if (lastRequestedAt != null && now.toEpochMilli() - lastRequestedAt.toEpochMilli() < UPLOAD_DEBOUNCE_MILLIS) {
            return
        }
        lastUploadRequestedAt = now

        if (serverUrl == null) {
            if (showResultNotice) notifyNotConfigured()
            return
        }
        if (!showResultNotice && !_state.value.isSignedIn) return
        if (_state.value.isSyncInProgress || _state.value.isAccountDeletionInProgress) return

        _state.value = _state.value.copy(isSyncInProgress = true, debugText = null)
        try {
            val metadata = replaceRemoteBackup(subscriptionRepository.fetchAll())
            _state.value = _state.value.copy(
                latestBackupAt = metadata.updatedAt,
                notice = if (showResultNotice) BackupAuthNotice.UPLOAD_SUCCESS else _state.value.notice,
                debugText = null,
                isSyncInProgress = false,
            )
        } catch (error: Throwable) {
            _state.value = _state.value.copy(
                notice = if (showResultNotice) BackupAuthNotice.UPLOAD_FAILED else _state.value.notice,
                debugText = describeBackupError(error, "upload"),
                isSyncInProgress = false,
            )
        }
    }

    suspend fun restoreLatestBackup() {
        if (serverUrl == null) {
            notifyNotConfigured()
            return
        }
        if (_state.value.isSyncInProgress || _state.value.isAccountDeletionInProgress) return

        _state.value = _state.value.copy(
            isSyncInProgress = true,
            isShowingRestorePromptAfterSignIn = false,
            debugText = null,
        )
        try {
            val metadata = fetchLatestBackupMetadata()
            if (metadata == null) {
                _state.value = _state.value.copy(
                    notice = BackupAuthNotice.RESTORE_EMPTY,
                    debugText = null,
                    isSyncInProgress = false,
                )
                return
            }

            val data = json.parseToJsonElement(authorizedRequest(path = "v1/backup/data", method = "GET")).jsonObject
            val remoteSubscriptions = data["items"].asJsonArray().map { it.jsonObject.toRemoteSubscriptionItem() }
            if (metadata.itemCount > 0 && remoteSubscriptions.isEmpty()) {
                throw FileNotFoundException("Backup items not found")
            }
            val remotePaymentHistories = data["payment_histories"].asJsonArray().map { it.jsonObject.toRemotePaymentHistory() }
            val restoredSubscriptions = buildSubscriptions(
                remoteSubscriptions = remoteSubscriptions,
                paymentHistories = remotePaymentHistories,
            )
            subscriptionRepository.replaceAll(restoredSubscriptions)
            reminderScheduler.syncAll(
                restoredSubscriptions.filter(Subscription::isActive),
                userPreferencesRepository.preferences.first(),
            )
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
        if (serverUrl == null) {
            notifyNotConfigured()
            return
        }
        if (_state.value.isSyncInProgress || _state.value.isAccountDeletionInProgress) return

        _state.value = _state.value.copy(isAccountDeletionInProgress = true, debugText = null)
        try {
            authorizedRequest(
                path = "v1/account/delete",
                method = "POST",
                body = buildJsonObject { put("reason", JsonPrimitive("user_requested")) }.toString(),
            )
            clearSession()
            _state.value = _state.value.copy(
                isSignedIn = false,
                accountIdentifier = null,
                latestBackupAt = null,
                notice = BackupAuthNotice.DELETE_ACCOUNT_SUCCESS,
                debugText = null,
                isAccountDeletionInProgress = false,
                isShowingRestorePromptAfterSignIn = false,
            )
            lastUploadRequestedAt = null
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
        if (serverUrl == null) return
        val data = intent.data ?: return
        if (!isBackupAuthDeepLink(data)) return

        isHandlingAuthCallback = true
        _state.value = _state.value.copy(isBusy = true)
        scope.launch {
            try {
                val code = data.getQueryParameter("code")
                    ?: throw IOException(data.getQueryParameter("error") ?: "Missing code")
                val verifier = prefs.getString(KEY_CODE_VERIFIER, null)
                    ?: throw IOException("Missing code_verifier")
                val payload = executeHttpRequest(
                    path = "v1/auth/kakao/exchange",
                    method = "POST",
                    body = buildJsonObject {
                        put("code", JsonPrimitive(code))
                        put("code_verifier", JsonPrimitive(verifier))
                    }.toString(),
                )
                prefs.edit().remove(KEY_CODE_VERIFIER).apply()
                val session = saveSession(payload)
                val accountIdentifier = session.email ?: session.userId
                _state.value = _state.value.copy(
                    isBusy = false,
                    isSignedIn = true,
                    accountIdentifier = accountIdentifier,
                    notice = BackupAuthNotice.SIGN_IN_SUCCESS,
                    debugText = null,
                )
                bootstrapBackupAfterSignIn()
            } catch (error: Throwable) {
                _state.value = _state.value.copy(
                    isBusy = false,
                    notice = BackupAuthNotice.SIGN_IN_FAILED,
                    debugText = describeBackupError(error, "sign_in"),
                )
            } finally {
                isHandlingAuthCallback = false
            }
        }
    }

    private suspend fun refreshBackupAuthState() {
        if (serverUrl == null) {
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
        val session = loadSession()
        if (session == null) {
            _state.value = _state.value.copy(
                isConfigured = true,
                isSignedIn = false,
                accountIdentifier = null,
                latestBackupAt = null,
                isBusy = false,
            )
            return
        }
        _state.value = _state.value.copy(
            isConfigured = true,
            isSignedIn = true,
            accountIdentifier = session.email ?: session.userId,
            isBusy = true,
        )
        try {
            _state.value = _state.value.copy(
                latestBackupAt = fetchLatestBackupMetadata()?.updatedAt,
                debugText = null,
                isBusy = false,
            )
        } catch (error: Throwable) {
            // 네트워크 오류로는 로그인을 풀지 않고, 세션이 서버에서 거부됐을 때만 로그아웃 처리함
            val isSignedIn = loadSession() != null
            _state.value = _state.value.copy(
                isSignedIn = isSignedIn,
                accountIdentifier = if (isSignedIn) _state.value.accountIdentifier else null,
                latestBackupAt = null,
                debugText = describeBackupError(error, "refresh_auth"),
                isBusy = false,
            )
        }
    }

    private suspend fun bootstrapBackupAfterSignIn() {
        try {
            val metadata = fetchLatestBackupMetadata()
            if (metadata != null) {
                _state.value = _state.value.copy(
                    latestBackupAt = metadata.updatedAt,
                    notice = BackupAuthNotice.SIGN_IN_RESTORE_PROMPT,
                    isShowingRestorePromptAfterSignIn = true,
                    debugText = null,
                )
            } else {
                val uploaded = replaceRemoteBackup(subscriptionRepository.fetchAll())
                _state.value = _state.value.copy(
                    latestBackupAt = uploaded.updatedAt,
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

    private suspend fun fetchLatestBackupMetadata(): BackupMetadata? = try {
        json.parseToJsonElement(authorizedRequest(path = "v1/backup", method = "GET")).jsonObject.toBackupMetadata()
    } catch (error: HttpException) {
        if (error.statusCode == HttpURLConnection.HTTP_NOT_FOUND) null else throw error
    }

    private suspend fun replaceRemoteBackup(subscriptions: List<Subscription>): BackupMetadata {
        val body = buildJsonObject {
            put("backup_version", JsonPrimitive(2))
            put("device_id", JsonNull)
            put("app_version", JsonNull)
            put("items", buildBackupItemsPayload(subscriptions))
            put("payment_histories", buildPaymentHistoriesPayload(subscriptions))
        }.toString()
        return json.parseToJsonElement(authorizedRequest(path = "v1/backup", method = "PUT", body = body))
            .jsonObject
            .toBackupMetadata()
    }

    private suspend fun authorizedRequest(path: String, method: String, body: String? = null): String {
        val session = validSession()
        return executeHttpRequest(path = path, method = method, accessToken = session.accessToken, body = body)
    }

    private suspend fun validSession(): Session = sessionMutex.withLock {
        val session = loadSession() ?: throw IOException("No active session")
        if (session.expiresAtMillis - System.currentTimeMillis() > TOKEN_REFRESH_MARGIN_MILLIS) {
            return@withLock session
        }
        try {
            saveSession(
                executeHttpRequest(
                    path = "v1/auth/refresh",
                    method = "POST",
                    body = buildJsonObject { put("refresh_token", JsonPrimitive(session.refreshToken)) }.toString(),
                ),
            )
        } catch (error: HttpException) {
            if (error.statusCode == HttpURLConnection.HTTP_UNAUTHORIZED) clearSession()
            throw error
        }
    }

    private fun saveSession(payload: String): Session {
        val root = json.parseToJsonElement(payload).jsonObject
        val user = root["user"]?.jsonObject ?: throw IOException("Missing field: user")
        val session = Session(
            accessToken = root.string("access_token"),
            refreshToken = root.string("refresh_token"),
            expiresAtMillis = System.currentTimeMillis() + (root["expires_in"]?.jsonPrimitive?.longOrNull ?: 0L) * 1000,
            userId = user.string("id"),
            email = user.optionalString("email")?.takeIf(String::isNotBlank),
        )
        prefs.edit()
            .putString(KEY_ACCESS_TOKEN, session.accessToken)
            .putString(KEY_REFRESH_TOKEN, session.refreshToken)
            .putLong(KEY_EXPIRES_AT, session.expiresAtMillis)
            .putString(KEY_USER_ID, session.userId)
            .putString(KEY_EMAIL, session.email)
            .apply()
        return session
    }

    private fun loadSession(): Session? {
        val accessToken = prefs.getString(KEY_ACCESS_TOKEN, null) ?: return null
        val refreshToken = prefs.getString(KEY_REFRESH_TOKEN, null) ?: return null
        val userId = prefs.getString(KEY_USER_ID, null) ?: return null
        return Session(
            accessToken = accessToken,
            refreshToken = refreshToken,
            expiresAtMillis = prefs.getLong(KEY_EXPIRES_AT, 0L),
            userId = userId,
            email = prefs.getString(KEY_EMAIL, null),
        )
    }

    private fun clearSession() {
        prefs.edit()
            .remove(KEY_ACCESS_TOKEN)
            .remove(KEY_REFRESH_TOKEN)
            .remove(KEY_EXPIRES_AT)
            .remove(KEY_USER_ID)
            .remove(KEY_EMAIL)
            .apply()
    }

    private fun notifyNotConfigured() {
        _state.value = _state.value.copy(
            notice = BackupAuthNotice.NOT_CONFIGURED,
            debugText = configurationDebugText(appContext, false),
        )
    }

    private suspend fun executeHttpRequest(
        path: String,
        method: String,
        accessToken: String? = null,
        body: String? = null,
    ): String = withContext(Dispatchers.IO) {
        val url = URL(Uri.parse(checkNotNull(serverUrl)).buildUpon().appendEncodedPath(path).build().toString())
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 15_000
            setRequestProperty("Accept", "application/json")
            if (accessToken != null) {
                setRequestProperty("Authorization", "Bearer $accessToken")
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
                throw HttpException(responseCode, message)
            }
            payload
        } finally {
            connection.disconnect()
        }
    }

    private fun buildBackupItemsPayload(subscriptions: List<Subscription>): JsonArray = buildJsonArray {
        subscriptions.forEachIndexed { index, subscription ->
            add(buildJsonObject {
                put("id", JsonPrimitive(subscription.id.toString()))
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
    }

    private fun buildPaymentHistoriesPayload(subscriptions: List<Subscription>): JsonArray = buildJsonArray {
        subscriptions.forEach { subscription ->
            val paidDates = (subscription.paymentHistoryDates + listOfNotNull(subscription.lastPaymentDate))
                .distinct()
                .sorted()
            paidDates.forEach { paidAt ->
                add(buildJsonObject {
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
    }

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
        updatedAt = parseInstantValue(string("updated_at")),
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
        nextBillingDate = parseInstantValue(string("next_billing_date")),
        lastPaymentDate = optionalString("last_payment_date")?.let(::parseInstantValue),
        iconKey = string("icon_key"),
        iconColorKey = string("icon_color_key"),
        customCategoryName = optionalString("custom_category_name"),
        notificationsEnabled = boolean("notifications_enabled"),
        isAutoPayEnabled = boolean("is_auto_pay_enabled"),
        isPinned = boolean("is_pinned"),
        isActive = boolean("is_active"),
        memo = optionalString("memo"),
        sortOrder = int("sort_order"),
        createdAt = parseInstantValue(string("created_at")),
        updatedAt = parseInstantValue(string("updated_at")),
    )

    private fun JsonObject.toRemotePaymentHistory(): RemotePaymentHistory = RemotePaymentHistory(
        subscriptionId = string("subscription_id"),
        paidAt = parseInstantValue(string("paid_at")),
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

    private fun JsonElement?.asJsonArray(): JsonArray =
        if (this == null || this is JsonNull) JsonArray(emptyList()) else jsonArray

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

    private data class Session(
        val accessToken: String,
        val refreshToken: String,
        val expiresAtMillis: Long,
        val userId: String,
        val email: String?,
    )

    private class HttpException(val statusCode: Int, message: String) : IOException(message)

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
        private const val UPLOAD_DEBOUNCE_MILLIS = 800L
        private const val TOKEN_REFRESH_MARGIN_MILLIS = 60_000L

        private const val PREFS_NAME = "payboard_backup_auth"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_EXPIRES_AT = "expires_at"
        private const val KEY_USER_ID = "user_id"
        private const val KEY_EMAIL = "email"
        private const val KEY_CODE_VERIFIER = "kakao_code_verifier"

        private fun base64Url(bytes: ByteArray): String =
            Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_PADDING or Base64.NO_WRAP)

        private fun configurationDebugText(
            context: Context,
            isConfigured: Boolean,
        ): String {
            val serverUrl = normalizedMetaDataValue(context, "PAYBOARD_SERVER_URL") ?: "<nil>"
            return listOf(
                "PAYBOARD_SERVER_URL: $serverUrl",
                "isBackupConfigured: $isConfigured",
            ).joinToString(separator = "\n")
        }

        private fun parseInstantValue(value: String): Instant =
            runCatching { Instant.parse(value) }
                .getOrElse { OffsetDateTime.parse(value).toInstant() }

        private fun isBackupAuthDeepLink(uri: Uri): Boolean =
            uri.scheme == DEEP_LINK_SCHEME &&
                uri.host == DEEP_LINK_HOST &&
                uri.path == DEEP_LINK_PATH

        private fun normalizedMetaDataValue(context: Context, key: String): String? {
            val applicationInfo = context.packageManager.getApplicationInfo(
                context.packageName,
                PackageManager.GET_META_DATA,
            )
            val rawValue = applicationInfo.metaData?.getString(key) ?: return null
            val trimmed = rawValue.trim()
            return trimmed.takeIf { it.isNotEmpty() && !it.startsWith("$") }
        }
    }
}
