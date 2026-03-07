package kr.co.cdd.payboard.core.app

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
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
        factory = SettingsViewModel.factory(container.userPreferencesRepository),
    )
    val boardViewModel: BoardViewModel = viewModel(
        factory = BoardViewModel.factory(container.subscriptionRepository),
    )
    val archiveViewModel: ArchiveViewModel = viewModel(
        factory = ArchiveViewModel.factory(container.subscriptionRepository),
    )
    val preferences by settingsViewModel.preferences.collectAsStateWithLifecycle()
    val navController = rememberNavController()
    val startDestination = remember(preferences.initialScreen) {
        if (preferences.initialScreen == InitialScreen.CALENDAR) Route.Calendar.route else Route.Board.route
    }
    val darkTheme = when (preferences.appearance) {
        AppAppearance.SYSTEM -> isSystemInDarkTheme()
        AppAppearance.LIGHT -> false
        AppAppearance.DARK -> true
    }

    PayBoardTheme(darkTheme = darkTheme) {
        val currentRoute = navController.currentBackStackEntryAsState().value?.destination?.route

        Scaffold(
            bottomBar = {
                NavigationBar {
                    Route.entries.forEach { route ->
                        NavigationBarItem(
                            selected = currentRoute == route.route,
                            onClick = {
                                navController.navigate(route.route) {
                                    launchSingleTop = true
                                    restoreState = true
                                    popUpTo(navController.graph.startDestinationId) {
                                        saveState = true
                                    }
                                }
                            },
                            icon = { Icon(route.icon, contentDescription = route.label) },
                            label = { Text(route.label) },
                        )
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
    }
}

private enum class Route(
    val route: String,
    val label: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
) {
    Board("board", "Board", Icons.Default.Home),
    Calendar("calendar", "Calendar", Icons.Default.DateRange),
    Archive("archive", "Archive", Icons.Default.Star),
    Settings("settings", "Settings", Icons.Default.Settings),
}
