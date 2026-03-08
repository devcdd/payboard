package kr.co.cdd.payboard.core.app

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.List
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import kr.co.cdd.payboard.core.designsystem.i18n.LocalPayBoardStrings
import kr.co.cdd.payboard.core.designsystem.i18n.rememberPayBoardStrings
import kr.co.cdd.payboard.core.designsystem.theme.ColorTokens
import kr.co.cdd.payboard.core.designsystem.theme.PayBoardShapes
import kr.co.cdd.payboard.core.designsystem.theme.PayBoardTheme
import kr.co.cdd.payboard.core.domain.model.AppAppearance
import kr.co.cdd.payboard.core.domain.model.InitialScreen
import kr.co.cdd.payboard.feature.archive.ArchiveRoute
import kr.co.cdd.payboard.feature.archive.ArchiveViewModel
import kr.co.cdd.payboard.feature.board.BoardDisplayMode
import kr.co.cdd.payboard.feature.board.BoardRoute
import kr.co.cdd.payboard.feature.board.BoardViewModel
import kr.co.cdd.payboard.feature.settings.SettingsRoute
import kr.co.cdd.payboard.feature.settings.SettingsViewModel

@Composable
fun PayBoardApp() {
    val container = rememberAppContainer()
    val settingsViewModel: SettingsViewModel = viewModel(
        factory = SettingsViewModel.factory(
            repository = container.userPreferencesRepository,
            subscriptionRepository = container.subscriptionRepository,
            backupAuthManager = container.backupAuthManager,
            notificationSettingsManager = container.notificationSettingsManager,
            reminderScheduler = container.subscriptionReminderScheduler,
        ),
    )
    val boardViewModel: BoardViewModel = viewModel(
        factory = BoardViewModel.factory(
            repository = container.subscriptionRepository,
            backupAuthManager = container.backupAuthManager,
            userPreferencesRepository = container.userPreferencesRepository,
            reminderScheduler = container.subscriptionReminderScheduler,
        ),
    )
    val archiveViewModel: ArchiveViewModel = viewModel(
        factory = ArchiveViewModel.factory(
            repository = container.subscriptionRepository,
            backupAuthManager = container.backupAuthManager,
            userPreferencesRepository = container.userPreferencesRepository,
            reminderScheduler = container.subscriptionReminderScheduler,
        ),
    )
    val preferences by settingsViewModel.preferences.collectAsStateWithLifecycle()
    val backupAuthState by settingsViewModel.backupAuthState.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    val startDestination = remember(preferences.initialScreen) {
        if (preferences.initialScreen == InitialScreen.CALENDAR) Route.Calendar.route else Route.Board.route
    }
    val darkTheme = when (preferences.appearance) {
        AppAppearance.SYSTEM -> isSystemInDarkTheme()
        AppAppearance.LIGHT -> false
        AppAppearance.DARK -> true
    }
    val strings = rememberPayBoardStrings(preferences.language)

    PayBoardTheme(darkTheme = darkTheme) {
        CompositionLocalProvider(LocalPayBoardStrings provides strings) {
            LaunchedEffect(boardViewModel) {
                boardViewModel.bootstrapOnAppStart()
            }
            val currentRoute = navController.currentBackStackEntryAsState().value?.destination?.route

            Scaffold(
                bottomBar = {
                    Surface {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .navigationBarsPadding()
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Route.entries.forEach { route ->
                                val label = when (route) {
                                    Route.Board -> strings.routeBoard
                                    Route.Calendar -> strings.routeCalendar
                                    Route.Archive -> strings.routeArchive
                                    Route.Settings -> strings.routeSettings
                                }
                                val selected = currentRoute == route.route
                                BottomBarItem(
                                    modifier = Modifier.weight(1f),
                                    selected = selected,
                                    label = label,
                                    icon = route.icon,
                                    onClick = {
                                        navController.navigate(route.route) {
                                            launchSingleTop = true
                                            restoreState = true
                                            popUpTo(navController.graph.startDestinationId) {
                                                saveState = true
                                            }
                                        }
                                    },
                                )
                            }
                        }
                    }
                },
            ) { innerPadding ->
                NavHost(
                    navController = navController,
                    startDestination = startDestination,
                    modifier = androidx.compose.ui.Modifier.padding(innerPadding),
                ) {
                    composable(Route.Board.route) {
                        BoardRoute(
                            viewModel = boardViewModel,
                            displayMode = BoardDisplayMode.BOARD,
                            isSearchVisible = preferences.boardSearchVisible,
                        )
                    }
                    composable(Route.Calendar.route) {
                        BoardRoute(
                            viewModel = boardViewModel,
                            displayMode = BoardDisplayMode.CALENDAR,
                            isSearchVisible = preferences.boardSearchVisible,
                        )
                    }
                    composable(Route.Archive.route) {
                        ArchiveRoute(viewModel = archiveViewModel)
                    }
                    composable(Route.Settings.route) {
                        SettingsRoute(viewModel = settingsViewModel)
                    }
                }
            }

            if (backupAuthState.isShowingRestorePromptAfterSignIn) {
                AlertDialog(
                    onDismissRequest = settingsViewModel::skipRestoreAfterSignIn,
                    title = { Text(strings.backupRestorePromptTitle) },
                    text = { Text(strings.backupRestorePromptMessage) },
                    confirmButton = {
                        Button(onClick = settingsViewModel::confirmRestoreAfterSignIn) {
                            Text(strings.backupRestorePromptRestore)
                        }
                    },
                    dismissButton = {
                        Button(onClick = settingsViewModel::skipRestoreAfterSignIn) {
                            Text(strings.backupRestorePromptSkip)
                        }
                    },
                )
            }
        }
    }
}

private enum class Route(
    val route: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
) {
    Board("board", Icons.Default.Home),
    Calendar("calendar", Icons.Default.DateRange),
    Archive("archive", Icons.AutoMirrored.Filled.List),
    Settings("settings", Icons.Default.Settings),
}

@Composable
private fun BottomBarItem(
    selected: Boolean,
    label: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val containerColor = if (selected) {
        ColorTokens.Accent.copy(alpha = 0.14f)
    } else {
        androidx.compose.ui.graphics.Color.Transparent
    }
    val contentColor = if (selected) {
        ColorTokens.Accent
    } else {
        androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant
    }

    Box(
        modifier = modifier
            .clip(PayBoardShapes.Control)
            .background(containerColor)
            .clickable(onClick = onClick)
            .padding(horizontal = 10.dp, vertical = 8.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(4.dp),
        ) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = contentColor,
                modifier = Modifier.size(20.dp),
            )
            Text(
                text = label,
                color = contentColor,
                style = androidx.compose.material3.MaterialTheme.typography.labelMedium,
            )
        }
    }
}
