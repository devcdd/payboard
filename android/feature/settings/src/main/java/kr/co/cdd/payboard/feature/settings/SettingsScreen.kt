package kr.co.cdd.payboard.feature.settings

import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kr.co.cdd.payboard.core.data.backup.BackupAuthNotice
import kr.co.cdd.payboard.core.data.backup.BackupAuthState
import kr.co.cdd.payboard.core.data.notifications.NotificationPermissionAction
import kr.co.cdd.payboard.core.data.notifications.NotificationSettingsNotice
import kr.co.cdd.payboard.core.data.notifications.NotificationSettingsState
import kr.co.cdd.payboard.core.designsystem.component.PayBoardPanel
import kr.co.cdd.payboard.core.designsystem.i18n.LocalPayBoardStrings
import kr.co.cdd.payboard.core.designsystem.R as DesignSystemR
import kr.co.cdd.payboard.core.domain.model.AppAppearance
import kr.co.cdd.payboard.core.domain.model.AppLanguage
import kr.co.cdd.payboard.core.domain.model.InitialScreen
import kr.co.cdd.payboard.core.domain.model.ReminderOption
import kr.co.cdd.payboard.core.domain.model.UserPreferences
import java.time.ZoneId
import java.time.format.FormatStyle
import java.time.format.DateTimeFormatter
import java.util.Locale

@Composable
fun SettingsRoute(viewModel: SettingsViewModel) {
    val preferences by viewModel.preferences.collectAsStateWithLifecycle()
    val backupAuthState by viewModel.backupAuthState.collectAsStateWithLifecycle()
    val notificationSettingsState by viewModel.notificationSettingsState.collectAsStateWithLifecycle()
    SettingsScreen(
        preferences = preferences,
        backupAuthState = backupAuthState,
        notificationSettingsState = notificationSettingsState,
        onAppearanceSelected = viewModel::setAppearance,
        onLanguageSelected = viewModel::setLanguage,
        onInitialScreenSelected = viewModel::setInitialScreen,
        onBoardSearchVisibleChanged = viewModel::setBoardSearchVisible,
        onPushNotificationsChanged = viewModel::setPushNotificationsEnabled,
        onReminderOptionChanged = viewModel::toggleReminderOption,
        onReminderTimeChanged = viewModel::setReminderTime,
        onRefreshBackupState = viewModel::refreshBackupState,
        onRefreshNotificationState = viewModel::refreshNotificationState,
        onNotificationPermissionResult = viewModel::onNotificationPermissionResult,
        onOpenNotificationSettings = viewModel::openNotificationSettings,
        onSendTestReminder = viewModel::sendTestReminder,
        onSignInWithKakao = viewModel::signInWithKakao,
        onSignOut = viewModel::signOutBackup,
        onUploadBackup = viewModel::uploadBackup,
        onRestoreLatestBackup = viewModel::restoreLatestBackup,
        onDeleteBackupAccount = viewModel::deleteBackupAccount,
        onConfirmRestoreAfterSignIn = viewModel::confirmRestoreAfterSignIn,
        onSkipRestoreAfterSignIn = viewModel::skipRestoreAfterSignIn,
    )
}

@Composable
fun SettingsScreen(
    preferences: UserPreferences,
    backupAuthState: BackupAuthState,
    notificationSettingsState: NotificationSettingsState,
    onAppearanceSelected: (AppAppearance) -> Unit,
    onLanguageSelected: (AppLanguage) -> Unit,
    onInitialScreenSelected: (InitialScreen) -> Unit,
    onBoardSearchVisibleChanged: (Boolean) -> Unit,
    onPushNotificationsChanged: (Boolean) -> Unit,
    onReminderOptionChanged: (ReminderOption, Boolean) -> Unit,
    onReminderTimeChanged: (Int, Int) -> Unit,
    onRefreshBackupState: () -> Unit,
    onRefreshNotificationState: () -> Unit,
    onNotificationPermissionResult: (Boolean) -> Unit,
    onOpenNotificationSettings: () -> Unit,
    onSendTestReminder: () -> Unit,
    onSignInWithKakao: () -> Unit,
    onSignOut: () -> Unit,
    onUploadBackup: () -> Unit,
    onRestoreLatestBackup: () -> Unit,
    onDeleteBackupAccount: () -> Unit,
    onConfirmRestoreAfterSignIn: () -> Unit,
    onSkipRestoreAfterSignIn: () -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val strings = LocalPayBoardStrings.current
    var isShowingRestoreConfirm by remember { mutableStateOf(false) }
    var isShowingDeleteAccountConfirm by remember { mutableStateOf(false) }
    val requestNotificationPermission = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission(),
    ) { granted ->
        onNotificationPermissionResult(granted)
        onPushNotificationsChanged(granted)
    }

    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                onRefreshBackupState()
                onRefreshNotificationState()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Text(strings.settingsTitle, style = MaterialTheme.typography.headlineMedium)
        }

        item {
            PreferenceGroup(title = strings.appearance) {
                AppAppearance.entries.forEach { appearance ->
                    RadioRow(
                        label = strings.appearanceLabel(appearance),
                        selected = preferences.appearance == appearance,
                        onClick = { onAppearanceSelected(appearance) },
                    )
                }
            }
        }

        item {
            PreferenceGroup(title = strings.languageLabel) {
                AppLanguage.entries.forEach { language ->
                    RadioRow(
                        label = strings.languageLabel(language),
                        selected = preferences.language == language,
                        onClick = { onLanguageSelected(language) },
                    )
                }
            }
        }

        item {
            PreferenceGroup(title = strings.initialScreen) {
                InitialScreen.entries.forEach { screen ->
                    RadioRow(
                        label = strings.initialScreenLabel(screen),
                        selected = preferences.initialScreen == screen,
                        onClick = { onInitialScreenSelected(screen) },
                    )
                }
            }
        }

        item {
            PreferenceGroup(title = strings.behavior) {
                SwitchRow(
                    label = strings.showBoardSearch,
                    checked = preferences.boardSearchVisible,
                    onCheckedChange = onBoardSearchVisibleChanged,
                )
                SwitchRow(
                    label = strings.pushNotifications,
                    checked = preferences.pushNotificationsEnabled,
                    onCheckedChange = { isEnabled ->
                        if (!isEnabled) {
                            onPushNotificationsChanged(false)
                        } else {
                            when (notificationSettingsState.action) {
                                NotificationPermissionAction.REQUEST_PERMISSION -> {
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                        requestNotificationPermission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                                    } else {
                                        onPushNotificationsChanged(true)
                                    }
                                }
                                NotificationPermissionAction.OPEN_SETTINGS -> onOpenNotificationSettings()
                                null -> onPushNotificationsChanged(true)
                            }
                        }
                    },
                )
                Text(
                    text = strings.pushNotificationsCaption,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                when (notificationSettingsState.action) {
                    NotificationPermissionAction.REQUEST_PERMISSION -> {
                        Text(
                            text = strings.notificationsPermissionMessage,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                        Button(
                            onClick = {
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                    requestNotificationPermission.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                                }
                            },
                        ) {
                            Text(strings.allowNotifications)
                        }
                    }
                    NotificationPermissionAction.OPEN_SETTINGS -> {
                        Text(
                            text = strings.notificationsSettingsMessage,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error,
                        )
                        Button(onClick = onOpenNotificationSettings) {
                            Text(strings.openSystemSettings)
                        }
                    }
                    null -> Unit
                }
            }
        }

        item {
            PreferenceGroup(title = strings.reminderOptions) {
                ReminderOption.entries.forEach { option ->
                    SwitchRow(
                        label = strings.reminderOptionLabel(option),
                        checked = preferences.reminderOptions.contains(option),
                        onCheckedChange = { onReminderOptionChanged(option, it) },
                    )
                }
                SettingActionRow(
                    label = strings.reminderTime(preferences.reminderHour, preferences.reminderMinute),
                    onClick = {
                        TimePickerDialog(
                            context,
                            { _, hourOfDay, minute ->
                                onReminderTimeChanged(hourOfDay, minute)
                            },
                            preferences.reminderHour,
                            preferences.reminderMinute,
                            true,
                        ).show()
                    },
                )
                Button(
                    onClick = onSendTestReminder,
                    enabled = preferences.pushNotificationsEnabled && notificationSettingsState.action == null,
                ) {
                    Text(strings.sendTestReminder)
                }
                notificationSettingsState.notice?.let { notice ->
                    Text(
                        text = when (notice) {
                            NotificationSettingsNotice.TEST_SENT -> strings.testReminderSent
                            NotificationSettingsNotice.TEST_FAILED -> strings.testReminderFailed
                            NotificationSettingsNotice.PERMISSION_REQUIRED -> strings.notificationsPermissionMessage
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = if (notice == NotificationSettingsNotice.TEST_FAILED || notice == NotificationSettingsNotice.PERMISSION_REQUIRED) {
                            MaterialTheme.colorScheme.error
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }
            }
        }

        item {
            PreferenceGroup(title = strings.backup) {
                if (!backupAuthState.isConfigured) {
                    Text(
                        strings.backupNotConfigured,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error,
                    )
                } else if (backupAuthState.isSignedIn) {
                    if (backupAuthState.accountIdentifier != null) {
                        Text(
                            "${strings.connectedAccount}: ${backupAuthState.accountIdentifier}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                    }

                    val latestBackupText = backupAuthState.latestBackupAt?.let {
                        strings.backupLatestAt(formatBackupTimestamp(it, preferences.language))
                    }
                    Text(
                        text = latestBackupText ?: strings.backupLatestAtEmpty,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )

                    Button(
                        onClick = onUploadBackup,
                        enabled = !backupAuthState.isSyncInProgress && !backupAuthState.isAccountDeletionInProgress,
                    ) {
                        Text(strings.backupUpload)
                    }
                    Button(
                        onClick = { isShowingRestoreConfirm = true },
                        enabled = !backupAuthState.isSyncInProgress && !backupAuthState.isAccountDeletionInProgress,
                    ) {
                        Text(strings.backupRestore)
                    }
                    Button(
                        onClick = onSignOut,
                        enabled = !backupAuthState.isSyncInProgress && !backupAuthState.isAccountDeletionInProgress,
                    ) {
                        Text(strings.signOut)
                    }
                    Button(
                        onClick = { isShowingDeleteAccountConfirm = true },
                        enabled = !backupAuthState.isSyncInProgress && !backupAuthState.isAccountDeletionInProgress,
                    ) {
                        Text(strings.backupDeleteAccount)
                    }
                } else {
                    KakaoSignInButton(
                        enabled = !backupAuthState.isBusy,
                        onClick = onSignInWithKakao,
                    )
                }

                backupAuthState.notice?.let { notice ->
                    Text(
                        text = when (notice) {
                            BackupAuthNotice.NOT_CONFIGURED -> strings.backupNotConfigured
                            BackupAuthNotice.SIGN_IN_SUCCESS -> strings.backupSignInSuccess
                            BackupAuthNotice.SIGN_IN_FAILED -> strings.backupSignInFailed
                            BackupAuthNotice.SIGN_OUT_SUCCESS -> strings.backupSignOutSuccess
                            BackupAuthNotice.SIGN_OUT_FAILED -> strings.backupSignOutFailed
                            BackupAuthNotice.SIGN_IN_RESTORE_PROMPT -> strings.backupSignInRestorePrompt
                            BackupAuthNotice.SIGN_IN_AUTO_BACKUP_DONE -> strings.backupSignInAutoBackupDone
                            BackupAuthNotice.SIGN_IN_RESTORE_SKIPPED -> strings.backupSignInRestoreSkipped
                            BackupAuthNotice.UPLOAD_SUCCESS -> strings.backupUploadSuccess
                            BackupAuthNotice.UPLOAD_FAILED -> strings.backupUploadFailed
                            BackupAuthNotice.RESTORE_SUCCESS -> strings.backupRestoreSuccess
                            BackupAuthNotice.RESTORE_FAILED -> strings.backupRestoreFailed
                            BackupAuthNotice.RESTORE_EMPTY -> strings.backupRestoreEmpty
                            BackupAuthNotice.DELETE_ACCOUNT_SERVER_NOT_CONFIGURED -> strings.backupDeleteAccountServerNotConfigured
                            BackupAuthNotice.DELETE_ACCOUNT_SUCCESS -> strings.backupDeleteAccountSuccess
                            BackupAuthNotice.DELETE_ACCOUNT_FAILED -> strings.backupDeleteAccountFailed
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = if (notice in setOf(
                                BackupAuthNotice.NOT_CONFIGURED,
                                BackupAuthNotice.SIGN_IN_FAILED,
                                BackupAuthNotice.SIGN_OUT_FAILED,
                                BackupAuthNotice.UPLOAD_FAILED,
                                BackupAuthNotice.RESTORE_FAILED,
                                BackupAuthNotice.DELETE_ACCOUNT_SERVER_NOT_CONFIGURED,
                                BackupAuthNotice.DELETE_ACCOUNT_FAILED,
                            )
                        ) {
                            MaterialTheme.colorScheme.error
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        },
                    )
                }

                if (backupAuthState.isBusy) {
                    Text(
                        text = strings.backupLoading,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

                if (backupAuthState.isAccountDeletionInProgress) {
                    Text(
                        text = strings.backupDeleteAccountInProgress,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else if (backupAuthState.isSyncInProgress) {
                    Text(
                        text = strings.backupSyncInProgress,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }

            }
        }

        item {
            PreferenceGroup(title = strings.contact) {
                SettingActionRow(
                    label = strings.contactEmail,
                    onClick = { openSupportEmail(context) },
                )
                SettingActionRow(
                    label = strings.contactInstagram,
                    onClick = { openInstagram(context) },
                )
                Text(
                    text = strings.contactCaption,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
    }

    if (isShowingRestoreConfirm) {
        AlertDialog(
            onDismissRequest = { isShowingRestoreConfirm = false },
            title = { Text(strings.backupRestoreConfirmTitle) },
            text = { Text(strings.backupRestoreConfirmMessage) },
            confirmButton = {
                Button(
                    onClick = {
                        isShowingRestoreConfirm = false
                        onRestoreLatestBackup()
                    },
                ) {
                    Text(strings.backupRestoreConfirmAction)
                }
            },
            dismissButton = {
                Button(onClick = { isShowingRestoreConfirm = false }) {
                    Text(strings.cancel)
                }
            },
        )
    }

    if (isShowingDeleteAccountConfirm) {
        AlertDialog(
            onDismissRequest = { isShowingDeleteAccountConfirm = false },
            title = { Text(strings.backupDeleteAccountConfirmTitle) },
            text = { Text(strings.backupDeleteAccountConfirmMessage(backupAuthState.accountIdentifier)) },
            confirmButton = {
                Button(
                    onClick = {
                        isShowingDeleteAccountConfirm = false
                        onDeleteBackupAccount()
                    },
                ) {
                    Text(strings.backupDeleteAccountConfirmAction)
                }
            },
            dismissButton = {
                Button(onClick = { isShowingDeleteAccountConfirm = false }) {
                    Text(strings.cancel)
                }
            },
        )
    }
}

@Composable
private fun KakaoSignInButton(
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val strings = LocalPayBoardStrings.current

    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 52.dp),
        shape = RoundedCornerShape(12.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFFFEE500),
            contentColor = Color(0xFF191919),
            disabledContainerColor = Color(0xFFFEE500).copy(alpha = 0.5f),
            disabledContentColor = Color(0xFF191919).copy(alpha = 0.7f),
        ),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Image(
                painter = painterResource(DesignSystemR.drawable.icon_kakao),
                contentDescription = null,
                modifier = Modifier.size(18.dp),
            )
            Text(
                text = strings.signInWithKakao,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

private fun formatBackupTimestamp(
    instant: java.time.Instant,
    language: AppLanguage,
): String {
    val locale = Locale.forLanguageTag(language.code)
    val formatter = DateTimeFormatter
        .ofLocalizedDateTime(FormatStyle.MEDIUM, FormatStyle.SHORT)
        .withLocale(locale)
        .withZone(ZoneId.systemDefault())
    return formatter.format(instant)
}

private fun openSupportEmail(context: Context) {
    openExternalIntent(
        context = context,
        intent = Intent(Intent.ACTION_SENDTO, Uri.parse(SUPPORT_EMAIL_URI)),
    )
}

private fun openInstagram(context: Context) {
    openExternalIntent(
        context = context,
        intent = Intent(Intent.ACTION_VIEW, Uri.parse(INSTAGRAM_URI)),
    )
}

private fun openExternalIntent(
    context: Context,
    intent: Intent,
) {
    val launchIntent = intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    if (launchIntent.resolveActivity(context.packageManager) != null) {
        context.startActivity(launchIntent)
    }
}

@Composable
private fun PreferenceGroup(
    title: String,
    content: @Composable () -> Unit,
) {
    PayBoardPanel {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            content()
        }
    }
}

@Composable
private fun RadioRow(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, modifier = Modifier.padding(top = 12.dp))
        RadioButton(selected = selected, onClick = onClick)
    }
}

@Composable
private fun SwitchRow(
    label: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    androidx.compose.foundation.layout.Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, modifier = Modifier.padding(top = 12.dp))
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun SettingActionRow(
    label: String,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label)
        Spacer(modifier = Modifier.weight(1f))
    }
}

private const val SUPPORT_EMAIL_URI = "mailto:developer.cdd@gmail.com"
private const val INSTAGRAM_URI = "https://www.instagram.com/payboard.app/"
