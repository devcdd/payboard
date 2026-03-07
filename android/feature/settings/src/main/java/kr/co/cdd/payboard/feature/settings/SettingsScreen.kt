package kr.co.cdd.payboard.feature.settings

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kr.co.cdd.payboard.core.designsystem.component.PayBoardPanel
import kr.co.cdd.payboard.core.domain.model.AppAppearance
import kr.co.cdd.payboard.core.domain.model.AppLanguage
import kr.co.cdd.payboard.core.domain.model.InitialScreen
import kr.co.cdd.payboard.core.domain.model.ReminderOption
import kr.co.cdd.payboard.core.domain.model.UserPreferences

@Composable
fun SettingsRoute(viewModel: SettingsViewModel) {
    val preferences by viewModel.preferences.collectAsStateWithLifecycle()
    SettingsScreen(
        preferences = preferences,
        onAppearanceSelected = viewModel::setAppearance,
        onLanguageSelected = viewModel::setLanguage,
        onInitialScreenSelected = viewModel::setInitialScreen,
        onBoardSearchVisibleChanged = viewModel::setBoardSearchVisible,
        onPushNotificationsChanged = viewModel::setPushNotificationsEnabled,
        onReminderOptionChanged = viewModel::toggleReminderOption,
    )
}

@Composable
fun SettingsScreen(
    preferences: UserPreferences,
    onAppearanceSelected: (AppAppearance) -> Unit,
    onLanguageSelected: (AppLanguage) -> Unit,
    onInitialScreenSelected: (InitialScreen) -> Unit,
    onBoardSearchVisibleChanged: (Boolean) -> Unit,
    onPushNotificationsChanged: (Boolean) -> Unit,
    onReminderOptionChanged: (ReminderOption, Boolean) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Settings", style = MaterialTheme.typography.headlineMedium)
                Text(
                    "Android keeps the same preference model as iOS first. Backup and account flows come next.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        item {
            PreferenceGroup(title = "Appearance") {
                AppAppearance.entries.forEach { appearance ->
                    RadioRow(
                        label = appearance.label,
                        selected = preferences.appearance == appearance,
                        onClick = { onAppearanceSelected(appearance) },
                    )
                }
            }
        }

        item {
            PreferenceGroup(title = "Language") {
                AppLanguage.entries.forEach { language ->
                    RadioRow(
                        label = language.label,
                        selected = preferences.language == language,
                        onClick = { onLanguageSelected(language) },
                    )
                }
            }
        }

        item {
            PreferenceGroup(title = "Initial Screen") {
                InitialScreen.entries.forEach { screen ->
                    RadioRow(
                        label = screen.label,
                        selected = preferences.initialScreen == screen,
                        onClick = { onInitialScreenSelected(screen) },
                    )
                }
            }
        }

        item {
            PreferenceGroup(title = "Behavior") {
                SwitchRow(
                    label = "Show board search",
                    checked = preferences.boardSearchVisible,
                    onCheckedChange = onBoardSearchVisibleChanged,
                )
                SwitchRow(
                    label = "Push notifications",
                    checked = preferences.pushNotificationsEnabled,
                    onCheckedChange = onPushNotificationsChanged,
                )
            }
        }

        item {
            PreferenceGroup(title = "Reminder Options") {
                ReminderOption.entries.forEach { option ->
                    SwitchRow(
                        label = option.label,
                        checked = preferences.reminderOptions.contains(option),
                        onCheckedChange = { onReminderOptionChanged(option, it) },
                    )
                }
                Text(
                    text = "Reminder time ${preferences.reminderHour.toString().padStart(2, '0')}:${preferences.reminderMinute.toString().padStart(2, '0')}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }

        item {
            PreferenceGroup(title = "Backup") {
                Text(
                    "Supabase backup, sign-in, and account deletion are intentionally deferred until the core flows are stable.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
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
