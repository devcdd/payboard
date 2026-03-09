package kr.co.cdd.payboard.feature.board

import android.app.DatePickerDialog
import android.content.Context
import android.view.HapticFeedbackConstants
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectDragGesturesAfterLongPress
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.GridItemSpan
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items as gridItems
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.ArrowDropUp
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Circle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.DragIndicator
import androidx.compose.material.icons.filled.DoneAll
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.FilterList
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material.icons.filled.Unarchive
import androidx.compose.material.icons.filled.ViewModule
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.zIndex
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kr.co.cdd.payboard.core.designsystem.component.PayBoardPanel
import kr.co.cdd.payboard.core.designsystem.component.PayBoardIconBadge
import kr.co.cdd.payboard.core.designsystem.component.SubscriptionCardView
import kr.co.cdd.payboard.core.designsystem.component.SubscriptionCardSize
import kr.co.cdd.payboard.core.designsystem.icon.PresetIcon
import kr.co.cdd.payboard.core.designsystem.icon.PresetIconCatalog
import kr.co.cdd.payboard.core.designsystem.i18n.LocalPayBoardStrings
import kr.co.cdd.payboard.core.designsystem.i18n.PayBoardStrings
import kr.co.cdd.payboard.core.designsystem.theme.ColorTokens
import kr.co.cdd.payboard.core.designsystem.theme.PayBoardShapes
import kr.co.cdd.payboard.core.domain.model.BillingCycle
import kr.co.cdd.payboard.core.domain.model.Subscription
import kr.co.cdd.payboard.core.domain.model.SubscriptionCategory
import kotlin.math.abs
import kotlin.math.roundToInt
import java.math.BigDecimal
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.TextStyle
import java.time.temporal.ChronoUnit
import java.time.temporal.WeekFields
import java.util.UUID
import sh.calvin.reorderable.ReorderableItem
import sh.calvin.reorderable.rememberReorderableLazyGridState

@Composable
fun BoardRoute(
    viewModel: BoardViewModel,
    displayMode: BoardDisplayMode,
    isSearchVisible: Boolean,
) {
    val state by viewModel.uiState.collectAsStateWithLifecycle()
    BoardScreen(
        state = state,
        displayMode = displayMode,
        isSearchVisible = isSearchVisible,
        onSearchQueryChange = viewModel::updateSearchQuery,
        onFilterSelected = viewModel::updateFilter,
        onMarkPaymentComplete = viewModel::markPaymentComplete,
        onArchive = viewModel::archive,
        onCreateSubscription = viewModel::create,
        onUpdateSubscription = viewModel::update,
        onDeleteSubscription = viewModel::delete,
        onDeleteSubscriptions = viewModel::delete,
        onMarkPaymentCompleteSelected = viewModel::markPaymentComplete,
        onArchiveSelected = viewModel::archive,
        onUpdateNextBillingDate = viewModel::updateNextBillingDate,
        onCancelPaymentComplete = viewModel::cancelPaymentComplete,
        onCancelPaymentCompleteSelected = viewModel::cancelPaymentComplete,
        onSetPinned = viewModel::setPinned,
        onClearError = viewModel::clearError,
    )
}

@Composable
fun BoardScreen(
    state: BoardUiState,
    displayMode: BoardDisplayMode,
    isSearchVisible: Boolean,
    onSearchQueryChange: (String) -> Unit,
    onFilterSelected: (BoardFilter) -> Unit,
    onMarkPaymentComplete: (Subscription) -> Unit,
    onArchive: (Subscription) -> Unit,
    onCreateSubscription: (Subscription) -> Unit,
    onUpdateSubscription: (Subscription) -> Unit,
    onDeleteSubscription: (Subscription) -> Unit,
    onDeleteSubscriptions: (Set<UUID>) -> Unit,
    onMarkPaymentCompleteSelected: (Set<UUID>) -> Unit,
    onArchiveSelected: (Set<UUID>) -> Unit,
    onUpdateNextBillingDate: (Set<UUID>, Instant) -> Unit,
    onCancelPaymentComplete: (Subscription) -> Unit,
    onCancelPaymentCompleteSelected: (Set<UUID>) -> Unit,
    onSetPinned: (Subscription, Boolean) -> Unit,
    onClearError: () -> Unit,
) {
    val context = LocalContext.current
    val view = LocalView.current
    val boardPrefs = remember(context) { context.getSharedPreferences("payboard.board", Context.MODE_PRIVATE) }
    val strings = LocalPayBoardStrings.current
    var isDashboardExpanded by rememberSaveable { mutableStateOf(false) }
    val restoredFilter = remember(boardPrefs) {
        BoardFilter.fromStorageValue(boardPrefs.getString("board.selectedFilter", null))
    }
    var hasRestoredBoardPreferences by rememberSaveable { mutableStateOf(false) }
    var columnsCount by rememberSaveable {
        mutableIntStateOf(boardPrefs.getInt("board.columnsCount", 2).coerceIn(1, 3))
    }
    var displayedMonth by remember { mutableStateOf(YearMonth.now()) }
    var selectedCalendarDate by rememberSaveable { mutableStateOf(LocalDate.now()) }
    var isMonthSelectorVisible by remember { mutableStateOf(false) }
    var isSelectionMode by remember { mutableStateOf(false) }
    var isCustomSortEditing by rememberSaveable { mutableStateOf(false) }
    var selectedSubscriptionIds by remember { mutableStateOf(emptySet<UUID>()) }
    var selectedSort by rememberSaveable {
        mutableStateOf(BoardSortOption.fromStorageValue(boardPrefs.getString("board.selectedSort", null)))
    }
    var activeBoardDragId by remember { mutableStateOf<UUID?>(null) }
    var previewBoardOrderIds by remember { mutableStateOf<List<UUID>>(emptyList()) }
    var editorSheet by remember { mutableStateOf<EditorSheet?>(null) }
    var quickIconTarget by remember { mutableStateOf<Subscription?>(null) }
    var quickIconQuery by remember { mutableStateOf("") }
    var pendingDeleteSubscription by remember { mutableStateOf<Subscription?>(null) }
    var pendingBulkDeleteIds by remember { mutableStateOf<Set<UUID>>(emptySet()) }
    var customSortOrderIds by remember { mutableStateOf(loadCustomSortOrder(boardPrefs)) }
    val boardGridState = rememberLazyGridState()
    val boardSubscriptions = remember(
        state.subscriptions,
        state.searchQuery,
        state.selectedFilter,
        displayedMonth,
        selectedSort,
        customSortOrderIds,
    ) {
        buildBoardSubscriptions(
            subscriptions = state.subscriptions,
            query = state.searchQuery,
            filter = state.selectedFilter,
            displayedMonth = displayedMonth,
            selectedSort = selectedSort,
            customSortOrderIds = customSortOrderIds,
        )
    }
    val monthSubscriptions = remember(state.subscriptions, displayedMonth) {
        buildMonthSubscriptions(
            subscriptions = state.subscriptions,
            displayedMonth = displayedMonth,
        )
    }
    val calendarDays = remember(displayedMonth, selectedCalendarDate, strings.locale) {
        buildCalendarDays(
            displayedMonth = displayedMonth,
            selectedDate = selectedCalendarDate,
            locale = strings.locale,
        )
    }
    val calendarMarkerByDate = remember(state.subscriptions, displayedMonth) {
        buildCalendarMarkerByDate(
            subscriptions = state.subscriptions,
            displayedMonth = displayedMonth,
        )
    }
    val selectedDateSubscriptions = remember(state.subscriptions, displayedMonth, selectedCalendarDate) {
        buildSelectedDateSubscriptions(
            subscriptions = state.subscriptions,
            displayedMonth = displayedMonth,
            selectedDate = selectedCalendarDate,
        )
    }
    val displayedMonthStart = remember(displayedMonth) {
        displayedMonth.atDay(1).toInstantAtStartOfDay()
    }
    val monthlyCurrencyCode = monthSubscriptions.firstOrNull()?.subscription?.currencyCode ?: "KRW"
    val monthlyTotal = monthSubscriptions.fold(BigDecimal.ZERO) { partial, item ->
        partial + item.subscription.amount
    }
    val categoryTotals = monthSubscriptions
        .groupBy { it.subscription.category }
        .mapValues { (_, items) ->
            items.fold(BigDecimal.ZERO) { partial, item -> partial + item.subscription.amount }
        }
        .toList()
        .sortedByDescending { (_, amount) -> amount }
    val boardVisibleIds = remember(boardSubscriptions) { boardSubscriptions.map { it.subscription.id } }
    val renderedBoardSubscriptions = remember(boardSubscriptions, previewBoardOrderIds, activeBoardDragId) {
        val lookup = boardSubscriptions.associateBy { it.subscription.id }
        val effectiveOrder = if (activeBoardDragId != null && previewBoardOrderIds.isNotEmpty()) {
            previewBoardOrderIds
        } else {
            boardVisibleIds
        }
        effectiveOrder.mapNotNull(lookup::get)
    }
    val boardHeaderCount = 2 +
        if (!isSelectionMode && isMonthSelectorVisible) 1 else 0 +
        if (isSearchVisible && !isSelectionMode) 1 else 0
    val showBulkActionBar = displayMode == BoardDisplayMode.BOARD && isSelectionMode && selectedSubscriptionIds.isNotEmpty()
    val showFab = displayMode != BoardDisplayMode.BOARD || !isSelectionMode
    val isSelectionDnDEnabled = displayMode == BoardDisplayMode.BOARD &&
        isSelectionMode &&
        selectedSubscriptionIds.isNotEmpty()
    val isCustomDnDEnabled = displayMode == BoardDisplayMode.BOARD &&
        selectedSort == BoardSortOption.CUSTOM &&
        isCustomSortEditing &&
        !isSelectionMode

    LaunchedEffect(Unit) {
        onFilterSelected(restoredFilter)
        hasRestoredBoardPreferences = true
    }

    LaunchedEffect(state.subscriptions.map { it.id }) {
        val synced = syncCustomSortOrder(customSortOrderIds, state.subscriptions.map { it.id })
        if (synced != customSortOrderIds) {
            customSortOrderIds = synced
            saveCustomSortOrder(boardPrefs, synced)
        }
    }

    LaunchedEffect(columnsCount) {
        boardPrefs.edit().putInt("board.columnsCount", columnsCount.coerceIn(1, 3)).apply()
    }

    LaunchedEffect(selectedSort) {
        boardPrefs.edit().putString("board.selectedSort", selectedSort.storageValue).apply()
        if (selectedSort != BoardSortOption.CUSTOM) {
            isCustomSortEditing = false
        }
    }

    LaunchedEffect(state.selectedFilter, hasRestoredBoardPreferences) {
        if (hasRestoredBoardPreferences) {
            boardPrefs.edit().putString("board.selectedFilter", state.selectedFilter.storageValue).apply()
        }
    }

    LaunchedEffect(boardVisibleIds, activeBoardDragId) {
        if (activeBoardDragId == null) {
            previewBoardOrderIds = boardVisibleIds
        }
    }

    fun clearSelection() {
        selectedSubscriptionIds = emptySet()
        isSelectionMode = false
        activeBoardDragId = null
        previewBoardOrderIds = boardVisibleIds
    }

    fun prepareCustomSortForEdit() {
        if (selectedSort != BoardSortOption.CUSTOM) {
            customSortOrderIds = boardVisibleIds + customSortOrderIds.filterNot { it in boardVisibleIds.toSet() }
            saveCustomSortOrder(boardPrefs, customSortOrderIds)
            selectedSort = BoardSortOption.CUSTOM
        }
    }

    fun enterCustomSortEditing() {
        prepareCustomSortForEdit()
        selectedSubscriptionIds = emptySet()
        isSelectionMode = false
        isMonthSelectorVisible = false
        isCustomSortEditing = true
    }

    fun toggleSelection(subscriptionId: UUID) {
        val updatedIds = if (selectedSubscriptionIds.contains(subscriptionId)) {
            selectedSubscriptionIds - subscriptionId
        } else {
            selectedSubscriptionIds + subscriptionId
        }
        selectedSubscriptionIds = updatedIds
        isSelectionMode = updatedIds.isNotEmpty()
    }

    val reorderableGridState = rememberReorderableLazyGridState(
        lazyGridState = boardGridState,
        scrollThresholdPadding = PaddingValues(24.dp),
    ) { from, to ->
        val fromIndex = from.index - boardHeaderCount
        val toIndex = to.index - boardHeaderCount
        val currentVisibleOrder = previewBoardOrderIds.ifEmpty { boardVisibleIds }
        if (fromIndex !in currentVisibleOrder.indices || toIndex !in currentVisibleOrder.indices) {
            return@rememberReorderableLazyGridState
        }
        val draggedId = activeBoardDragId ?: currentVisibleOrder.getOrNull(fromIndex) ?: return@rememberReorderableLazyGridState
        previewBoardOrderIds = reorderVisibleOrder(
            visibleOrder = currentVisibleOrder,
            draggedId = draggedId,
            targetIndex = toIndex,
            selectedIds = selectedSubscriptionIds,
            isSelectionMode = isSelectionMode,
        )
        view.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
    ) {
        if (displayMode == BoardDisplayMode.BOARD) {
            LazyVerticalGrid(
                columns = GridCells.Fixed(columnsCount.coerceIn(1, 3)),
                state = boardGridState,
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    top = 12.dp,
                    end = 16.dp,
                    bottom = if (showBulkActionBar) 156.dp else 92.dp,
                ),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item(span = { GridItemSpan(maxLineSpan) }) {
                    BoardHeaderSection(
                        displayMode = displayMode,
                        displayedMonth = displayedMonth,
                        isMonthSelectorVisible = isMonthSelectorVisible,
                        isSelectionMode = isSelectionMode,
                        isCustomSortEditing = isCustomSortEditing,
                        selectedCount = selectedSubscriptionIds.size,
                        selectedFilter = state.selectedFilter,
                        selectedSort = selectedSort,
                        columnsCount = columnsCount,
                        strings = strings,
                        onToggleMonthSelector = {
                            if (!isSelectionMode && !isCustomSortEditing) {
                                isMonthSelectorVisible = !isMonthSelectorVisible
                            }
                        },
                        onMonthSelected = { yearMonth ->
                            displayedMonth = yearMonth
                            isMonthSelectorVisible = false
                        },
                        onFilterSelected = onFilterSelected,
                        onSortSelected = { selectedSort = it },
                        onColumnsSelected = { columnsCount = it.coerceIn(1, 3) },
                        onCustomSortEditingChange = { isEditing ->
                            if (isEditing) {
                                enterCustomSortEditing()
                            } else {
                                isCustomSortEditing = false
                            }
                        },
                        onCancelSelection = ::clearSelection,
                    )
                }

                if (!isSelectionMode && isMonthSelectorVisible) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        InlineMonthSelector(
                            displayedMonth = displayedMonth,
                            strings = strings,
                            onMonthSelected = {
                                displayedMonth = it
                                isMonthSelectorVisible = false
                            },
                        )
                    }
                }

                if (isSearchVisible && !isSelectionMode) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        SearchField(
                            strings = strings,
                            query = state.searchQuery,
                            onQueryChange = onSearchQueryChange,
                        )
                    }
                }

                item(span = { GridItemSpan(maxLineSpan) }) {
                    DashboardSection(
                        totalMonthly = monthlyTotal,
                        currencyCode = monthlyCurrencyCode,
                        categoryTotals = categoryTotals,
                        strings = strings,
                        isExpanded = isDashboardExpanded,
                        onToggleExpanded = { isDashboardExpanded = !isDashboardExpanded },
                    )
                }

                if (renderedBoardSubscriptions.isEmpty()) {
                    item(span = { GridItemSpan(maxLineSpan) }) {
                        EmptyState(strings = strings)
                    }
                } else {
                    gridItems(
                        items = renderedBoardSubscriptions,
                        key = { it.subscription.id },
                    ) { item ->
                        ReorderableItem(
                            state = reorderableGridState,
                            key = item.subscription.id,
                        ) { isDragging ->
                            val reorderModifier = if (isSelectionDnDEnabled || isCustomDnDEnabled) {
                                Modifier.longPressDraggableHandle(
                                    onDragStarted = {
                                        activeBoardDragId = item.subscription.id
                                        previewBoardOrderIds = renderedBoardSubscriptions.map { it.subscription.id }
                                        view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                                    },
                                    onDragStopped = {
                                        val syncedFullOrder = syncCustomSortOrder(customSortOrderIds, state.subscriptions.map { it.id })
                                        val mergedOrder = mergeVisibleOrder(
                                            fullOrder = syncedFullOrder,
                                            visibleIds = boardVisibleIds.toSet(),
                                            reorderedVisibleIds = previewBoardOrderIds.ifEmpty { boardVisibleIds },
                                        )
                                        if (mergedOrder != customSortOrderIds) {
                                            customSortOrderIds = mergedOrder
                                            saveCustomSortOrder(boardPrefs, mergedOrder)
                                        }
                                        selectedSort = BoardSortOption.CUSTOM
                                        activeBoardDragId = null
                                        previewBoardOrderIds = boardVisibleIds
                                        view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                                    },
                                )
                            } else {
                                Modifier
                            }
                            Box(
                                modifier = Modifier.then(reorderModifier),
                            ) {
                                BoardCard(
                                    item = item,
                                    columnsCount = columnsCount,
                                    isSelectionMode = isSelectionMode,
                                    isCustomSortEditing = isCustomSortEditing,
                                    isSelected = selectedSubscriptionIds.contains(item.subscription.id),
                                    isDropTarget = false,
                                    referenceMonth = displayedMonthStart,
                                    modifier = Modifier.then(
                                        if (isDragging) {
                                            Modifier.zIndex(1f)
                                        } else {
                                            Modifier
                                        }
                                    ),
                                    onClick = {
                                        if (isSelectionMode) {
                                            toggleSelection(item.subscription.id)
                                        } else {
                                            editorSheet = EditorSheet.Edit(item.subscription)
                                        }
                                    },
                                    onLongClick = {
                                        if (!isSelectionMode) {
                                            isSelectionMode = true
                                            isMonthSelectorVisible = false
                                            toggleSelection(item.subscription.id)
                                        } else if (!selectedSubscriptionIds.contains(item.subscription.id)) {
                                            toggleSelection(item.subscription.id)
                                        }
                                    },
                                    onMarkPaymentComplete = { onMarkPaymentComplete(item.subscription) },
                                    onCancelPaymentComplete = { onCancelPaymentComplete(item.subscription) },
                                    onArchive = { onArchive(item.subscription) },
                                    onDelete = { pendingDeleteSubscription = item.subscription },
                                    onEdit = { editorSheet = EditorSheet.Edit(item.subscription) },
                                    onTogglePinned = { onSetPinned(item.subscription, !item.subscription.isPinned) },
                                    onChangeIcon = {
                                        quickIconQuery = ""
                                        quickIconTarget = item.subscription
                                    },
                                )
                            }
                        }
                    }
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    start = 16.dp,
                    top = 12.dp,
                    end = 16.dp,
                    bottom = if (showBulkActionBar) 156.dp else 92.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                item {
                    BoardHeaderSection(
                        displayMode = displayMode,
                        displayedMonth = displayedMonth,
                        isMonthSelectorVisible = false,
                        isSelectionMode = isSelectionMode,
                        isCustomSortEditing = isCustomSortEditing,
                        selectedCount = selectedSubscriptionIds.size,
                        selectedFilter = state.selectedFilter,
                        selectedSort = selectedSort,
                        columnsCount = columnsCount,
                        strings = strings,
                        onToggleMonthSelector = {},
                        onMonthSelected = { displayedMonth = it },
                        onFilterSelected = onFilterSelected,
                        onSortSelected = { selectedSort = it },
                        onColumnsSelected = { columnsCount = it.coerceIn(1, 3) },
                        onCustomSortEditingChange = { isCustomSortEditing = it },
                        onCancelSelection = ::clearSelection,
                    )
                }
                item {
                    DashboardSection(
                        totalMonthly = monthlyTotal,
                        currencyCode = monthlyCurrencyCode,
                        categoryTotals = categoryTotals,
                        strings = strings,
                        isExpanded = isDashboardExpanded,
                        onToggleExpanded = { isDashboardExpanded = !isDashboardExpanded },
                    )
                }
                item {
                    CalendarSection(
                        strings = strings,
                        displayedMonth = displayedMonth,
                        isMonthSelectorVisible = isMonthSelectorVisible,
                        calendarDays = calendarDays,
                        calendarMarkerByDate = calendarMarkerByDate,
                        selectedDateSubscriptions = selectedDateSubscriptions,
                        onToggleMonthSelector = {
                            isMonthSelectorVisible = !isMonthSelectorVisible
                        },
                        onMoveMonth = { offset ->
                            val nextMonth = displayedMonth.plusMonths(offset.toLong())
                            displayedMonth = nextMonth
                            selectedCalendarDate = nextMonth.atDay(
                                selectedCalendarDate.dayOfMonth.coerceAtMost(nextMonth.lengthOfMonth()),
                            )
                        },
                        onMonthSelected = { yearMonth ->
                            displayedMonth = yearMonth
                            selectedCalendarDate = yearMonth.atDay(
                                selectedCalendarDate.dayOfMonth.coerceAtMost(yearMonth.lengthOfMonth()),
                            )
                            isMonthSelectorVisible = false
                        },
                        onDateSelected = { date ->
                            selectedCalendarDate = date
                            displayedMonth = YearMonth.from(date)
                        },
                        onSubscriptionClick = { subscription ->
                            editorSheet = EditorSheet.Edit(subscription)
                        },
                    )
                }
            }
        }

        if (showFab) {
            FloatingActionButton(
                onClick = { editorSheet = EditorSheet.Create(UUID.randomUUID()) },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 16.dp, bottom = if (showBulkActionBar) 96.dp else 16.dp),
                containerColor = ColorTokens.Accent,
                contentColor = MaterialTheme.colorScheme.onPrimary,
                shape = CircleShape,
            ) {
                Icon(Icons.Default.Add, contentDescription = strings.addSubscription)
            }
        }

        if (showBulkActionBar) {
            BulkActionBar(
                selectedCount = selectedSubscriptionIds.size,
                strings = strings,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(horizontal = 16.dp, vertical = 16.dp)
                    .navigationBarsPadding(),
                onCompleteSelected = {
                    onMarkPaymentCompleteSelected(selectedSubscriptionIds)
                    clearSelection()
                },
                onCancelCompleteSelected = {
                    onCancelPaymentCompleteSelected(selectedSubscriptionIds)
                    clearSelection()
                },
                onChangeSelectedDate = {
                    val initialDate = boardSubscriptions
                        .firstOrNull { selectedSubscriptionIds.contains(it.subscription.id) }
                        ?.effectiveBillingDate
                        ?.toLocalDate()
                        ?: LocalDate.now()
                    DatePickerDialog(
                        context,
                        { _, year, month, dayOfMonth ->
                            onUpdateNextBillingDate(
                                selectedSubscriptionIds,
                                LocalDate.of(year, month + 1, dayOfMonth).toInstantAtStartOfDay(),
                            )
                            clearSelection()
                        },
                        initialDate.year,
                        initialDate.monthValue - 1,
                        initialDate.dayOfMonth,
                    ).show()
                },
                onArchiveSelected = {
                    onArchiveSelected(selectedSubscriptionIds)
                    clearSelection()
                },
                onDeleteSelected = {
                    pendingBulkDeleteIds = selectedSubscriptionIds
                },
            )
        }
    }

    when (val activeSheet = editorSheet) {
        null -> Unit
        is EditorSheet.Create -> {
            SubscriptionEditorSheet(
                strings = strings,
                original = null,
                displayedMonth = displayedMonth,
                onDismiss = { editorSheet = null },
                onConfirm = { created ->
                    onCreateSubscription(created)
                    editorSheet = null
                },
            )
        }
        is EditorSheet.Edit -> {
            SubscriptionEditorSheet(
                strings = strings,
                original = activeSheet.subscription,
                displayedMonth = displayedMonth,
                onDismiss = { editorSheet = null },
                onConfirm = { updated ->
                    onUpdateSubscription(updated)
                    editorSheet = null
                },
            )
        }
    }

    quickIconTarget?.let { subscription ->
        QuickIconSheet(
            strings = strings,
            query = quickIconQuery,
            onQueryChange = { quickIconQuery = it },
            onDismiss = {
                quickIconTarget = null
                quickIconQuery = ""
            },
            onSelect = { icon ->
                onUpdateSubscription(
                    subscription.copy(
                        iconKey = icon.key,
                        iconColorKey = icon.colorKey,
                        updatedAt = Instant.now(),
                    ),
                )
                quickIconTarget = null
                quickIconQuery = ""
            },
        )
    }

    pendingDeleteSubscription?.let { subscription ->
        AlertDialog(
            onDismissRequest = { pendingDeleteSubscription = null },
            title = { Text(strings.deleteSingle) },
            text = { Text(subscription.name) },
            confirmButton = {
                TextButton(
                    onClick = {
                        onDeleteSubscription(subscription)
                        pendingDeleteSubscription = null
                    },
                ) {
                    Text(
                        text = strings.deleteSingle,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingDeleteSubscription = null }) {
                    Text(strings.cancel)
                }
            },
        )
    }

    if (pendingBulkDeleteIds.isNotEmpty()) {
        AlertDialog(
            onDismissRequest = { pendingBulkDeleteIds = emptySet() },
            title = { Text(strings.deleteSelected) },
            text = { Text(strings.bulkDeleteConfirmMessage(pendingBulkDeleteIds.size)) },
            confirmButton = {
                TextButton(
                    onClick = {
                        onDeleteSubscriptions(pendingBulkDeleteIds)
                        pendingBulkDeleteIds = emptySet()
                        clearSelection()
                    },
                ) {
                    Text(
                        text = strings.deleteSelected,
                        color = MaterialTheme.colorScheme.error,
                    )
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingBulkDeleteIds = emptySet() }) {
                    Text(strings.cancel)
                }
            },
        )
    }

    if (state.errorMessage != null) {
        AlertDialog(
            onDismissRequest = onClearError,
            title = { Text(strings.errorTitle) },
            text = { Text(state.errorMessage?.takeIf { it.isNotBlank() } ?: strings.unknownError) },
            confirmButton = {
                TextButton(onClick = onClearError) {
                    Text(strings.confirm)
                }
            },
        )
    }
}

@Composable
private fun BoardHeaderSection(
    displayMode: BoardDisplayMode,
    displayedMonth: YearMonth,
    isMonthSelectorVisible: Boolean,
    isSelectionMode: Boolean,
    isCustomSortEditing: Boolean,
    selectedCount: Int,
    selectedFilter: BoardFilter,
    selectedSort: BoardSortOption,
    columnsCount: Int,
    strings: PayBoardStrings,
    onToggleMonthSelector: () -> Unit,
    onMonthSelected: (YearMonth) -> Unit,
    onFilterSelected: (BoardFilter) -> Unit,
    onSortSelected: (BoardSortOption) -> Unit,
    onColumnsSelected: (Int) -> Unit,
    onCustomSortEditingChange: (Boolean) -> Unit,
    onCancelSelection: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        if (displayMode == BoardDisplayMode.BOARD) {
            Row(
                modifier = Modifier
                    .clip(PayBoardShapes.Control)
                    .clickable(onClick = onToggleMonthSelector)
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = strings.monthYearTitle(displayedMonth),
                    style = MaterialTheme.typography.headlineMedium,
                    fontWeight = FontWeight.Bold,
                )
                Icon(
                    imageVector = if (isMonthSelectorVisible) Icons.Default.ArrowDropUp else Icons.Default.ArrowDropDown,
                    contentDescription = null,
                )
            }
        } else {
            Text(
                text = strings.routeCalendar,
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
            )
        }

        Spacer(modifier = Modifier.weight(1f))

        if (displayMode == BoardDisplayMode.BOARD) {
            if (isSelectionMode) {
                Text(
                    text = strings.selectedCount(selectedCount),
                    style = MaterialTheme.typography.bodyMedium,
                    color = payMutedColor(),
                )
                TextButton(onClick = onCancelSelection) {
                    Text(strings.cancel)
                }
            } else {
                BoardHeaderActions(
                    strings = strings,
                    selectedFilter = selectedFilter,
                    selectedSort = selectedSort,
                    columnsCount = columnsCount,
                    isCustomSortEditing = isCustomSortEditing,
                    onCustomSortEditingChange = onCustomSortEditingChange,
                    onSortSelected = onSortSelected,
                    onFilterSelected = onFilterSelected,
                    onColumnsSelected = onColumnsSelected,
                )
            }
        }
    }
}

@Composable
private fun BoardHeaderActions(
    strings: PayBoardStrings,
    selectedFilter: BoardFilter,
    selectedSort: BoardSortOption,
    columnsCount: Int,
    isCustomSortEditing: Boolean,
    onCustomSortEditingChange: (Boolean) -> Unit,
    onSortSelected: (BoardSortOption) -> Unit,
    onFilterSelected: (BoardFilter) -> Unit,
    onColumnsSelected: (Int) -> Unit,
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SortMenuButton(strings = strings, selectedSort = selectedSort, onSortSelected = onSortSelected)
        FilterMenuButton(strings = strings, selectedFilter = selectedFilter, onFilterSelected = onFilterSelected)
        LayoutMenuButton(strings = strings, columnsCount = columnsCount, onColumnsSelected = onColumnsSelected)
        if (isCustomSortEditing) {
            SurfaceActionButton(
                onClick = { onCustomSortEditingChange(false) },
            ) {
                Icon(
                    imageVector = Icons.Default.CheckCircle,
                    contentDescription = strings.doneCustomOrder,
                )
            }
        }
    }
}

@Composable
private fun SortMenuButton(
    strings: PayBoardStrings,
    selectedSort: BoardSortOption,
    onSortSelected: (BoardSortOption) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        SurfaceActionButton(onClick = { expanded = true }) {
            Icon(Icons.Default.SwapVert, contentDescription = strings.sortTitle)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            BoardSortOption.entries.forEach { option ->
                DropdownMenuItem(
                    text = { Text(strings.boardSortLabel(option)) },
                    onClick = {
                        expanded = false
                        onSortSelected(option)
                    },
                    trailingIcon = {
                        if (option == selectedSort) {
                            Icon(Icons.Default.Check, contentDescription = null)
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun FilterMenuButton(
    strings: PayBoardStrings,
    selectedFilter: BoardFilter,
    onFilterSelected: (BoardFilter) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        SurfaceActionButton(onClick = { expanded = true }) {
            Icon(Icons.Default.FilterList, contentDescription = strings.filter)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            BoardFilter.entries.forEach { filter ->
                DropdownMenuItem(
                    text = { Text(strings.boardFilterLabel(filter.label)) },
                    onClick = {
                        expanded = false
                        onFilterSelected(filter)
                    },
                    trailingIcon = {
                        if (filter == selectedFilter) {
                            Icon(Icons.Default.Check, contentDescription = null)
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun LayoutMenuButton(
    strings: PayBoardStrings,
    columnsCount: Int,
    onColumnsSelected: (Int) -> Unit,
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        SurfaceActionButton(onClick = { expanded = true }) {
            Icon(Icons.Default.ViewModule, contentDescription = strings.layout)
        }
        DropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            listOf(3, 2, 1).forEach { count ->
                DropdownMenuItem(
                    text = { Text(strings.boardLayoutLabel(count)) },
                    onClick = {
                        expanded = false
                        onColumnsSelected(count)
                    },
                    trailingIcon = {
                        if (count == columnsCount) {
                            Icon(Icons.Default.Check, contentDescription = null)
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun SurfaceActionButton(
    onClick: () -> Unit,
    content: @Composable () -> Unit,
) {
    Surface(
        modifier = Modifier
            .clip(CircleShape)
            .clickable(onClick = onClick),
        color = MaterialTheme.colorScheme.surface,
        shadowElevation = 2.dp,
    ) {
        Box(
            modifier = Modifier.padding(8.dp),
            contentAlignment = Alignment.Center,
        ) {
            content()
        }
    }
}

@Composable
private fun InlineMonthSelector(
    displayedMonth: YearMonth,
    strings: PayBoardStrings,
    onMonthSelected: (YearMonth) -> Unit,
) {
    val nowMonth = YearMonth.now()
    val listStart = remember(displayedMonth, nowMonth) {
        minYearMonth(nowMonth.minusMonths(12), displayedMonth.minusMonths(6))
    }
    val listEnd = remember(displayedMonth, nowMonth) {
        maxYearMonth(nowMonth.plusMonths(12), displayedMonth.plusMonths(6))
    }
    val monthOptions = remember(listStart, listEnd) {
        buildMonthOptions(listStart, listEnd)
    }
    val listState = rememberLazyListState()
    val currentIndex = remember(monthOptions, nowMonth) { monthOptions.indexOf(nowMonth).coerceAtLeast(0) }

    LaunchedEffect(monthOptions) {
        listState.scrollToItem((currentIndex - 2).coerceAtLeast(0))
    }

    PayBoardPanel {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                TextButton(onClick = { onMonthSelected(displayedMonth.minusMonths(1)) }) {
                    Text(strings.previousMonth)
                }
                Surface(
                    modifier = Modifier.clickable { onMonthSelected(nowMonth) },
                    color = if (displayedMonth == nowMonth) ColorTokens.Accent.copy(alpha = 0.12f) else MaterialTheme.colorScheme.surface,
                    shape = PayBoardShapes.Control,
                    tonalElevation = 1.dp,
                ) {
                    Text(
                        text = strings.currentMonth,
                        modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                        color = if (displayedMonth == nowMonth) ColorTokens.Accent else MaterialTheme.colorScheme.onSurface,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                TextButton(onClick = { onMonthSelected(displayedMonth.plusMonths(1)) }) {
                    Text(strings.nextMonth)
                }
            }
            LazyRow(
                state = listState,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                items(monthOptions) { yearMonth ->
                    val isSelected = yearMonth == displayedMonth
                    val isCurrent = yearMonth == nowMonth
                    Surface(
                        modifier = Modifier.clickable { onMonthSelected(yearMonth) },
                        color = if (isSelected) ColorTokens.Accent.copy(alpha = 0.12f) else MaterialTheme.colorScheme.surface,
                        shape = PayBoardShapes.Control,
                        tonalElevation = if (isSelected) 1.dp else 0.dp,
                    ) {
                        Text(
                            text = strings.monthOptionLabel(yearMonth),
                            modifier = Modifier
                                .then(
                                    if (isCurrent && !isSelected) {
                                        Modifier.border(
                                            width = 1.dp,
                                            color = ColorTokens.Accent.copy(alpha = 0.5f),
                                            shape = PayBoardShapes.Control,
                                        )
                                    } else {
                                        Modifier
                                    },
                                )
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = if (isSelected || isCurrent) FontWeight.SemiBold else FontWeight.Medium,
                            color = if (isSelected) ColorTokens.Accent else MaterialTheme.colorScheme.onSurface,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun SearchField(
    strings: PayBoardStrings,
    query: String,
    onQueryChange: (String) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(PayBoardShapes.Control)
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 12.dp, vertical = 11.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(Icons.Default.Search, contentDescription = null, tint = payMutedColor())
        BasicTextField(
            value = query,
            onValueChange = onQueryChange,
            modifier = Modifier.weight(1f),
            textStyle = MaterialTheme.typography.bodyLarge.copy(color = MaterialTheme.colorScheme.onSurface),
            singleLine = true,
            decorationBox = { innerTextField ->
                if (query.isBlank()) {
                    Text(
                        text = strings.searchSubscriptions,
                        style = MaterialTheme.typography.bodyLarge,
                        color = payMutedColor(),
                    )
                }
                innerTextField()
            },
        )
    }
}

@Composable
private fun DashboardSection(
    totalMonthly: BigDecimal,
    currencyCode: String,
    categoryTotals: List<Pair<SubscriptionCategory, BigDecimal>>,
    strings: PayBoardStrings,
    isExpanded: Boolean,
    onToggleExpanded: () -> Unit,
) {
    PayBoardPanel(
        modifier = Modifier.clickable(onClick = onToggleExpanded),
    ) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = strings.monthlyTotal,
                        style = MaterialTheme.typography.bodySmall,
                        color = payMutedColor(),
                    )
                    Text(
                        text = strings.formatCurrency(totalMonthly, currencyCode),
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.SemiBold,
                    )
                }
                Spacer(modifier = Modifier.weight(1f))
                Icon(
                    imageVector = if (isExpanded) Icons.Default.ArrowDropUp else Icons.Default.ArrowDropDown,
                    contentDescription = null,
                    tint = payMutedColor(),
                )
            }

            if (isExpanded) {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = strings.categorySummary,
                        style = MaterialTheme.typography.bodySmall,
                        color = payMutedColor(),
                    )
                    if (categoryTotals.isEmpty()) {
                        Text(
                            text = strings.noActiveSubscriptions,
                            style = MaterialTheme.typography.bodyMedium,
                            color = payMutedColor(),
                        )
                    } else {
                        categoryTotals.forEach { (category, amount) ->
                            Row {
                                Text(
                                    text = strings.categoryLabel(category),
                                    style = MaterialTheme.typography.bodyMedium,
                                )
                                Spacer(modifier = Modifier.weight(1f))
                                Text(
                                    text = strings.formatCurrency(amount, currencyCode),
                                    style = MaterialTheme.typography.bodyMedium,
                                    fontWeight = FontWeight.SemiBold,
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun BoardCard(
    item: DisplayedSubscription,
    columnsCount: Int,
    isSelectionMode: Boolean,
    isCustomSortEditing: Boolean,
    isSelected: Boolean,
    isDropTarget: Boolean,
    referenceMonth: Instant,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
    onLongClick: () -> Unit,
    onMarkPaymentComplete: () -> Unit,
    onCancelPaymentComplete: () -> Unit,
    onArchive: () -> Unit,
    onDelete: () -> Unit,
    onEdit: () -> Unit,
    onTogglePinned: () -> Unit,
    onChangeIcon: () -> Unit,
) {
    val strings = LocalPayBoardStrings.current
    var menuExpanded by remember(item.subscription.id) { mutableStateOf(false) }
    val showInlineActionMenu = !isSelectionMode && !isCustomSortEditing && columnsCount == 2
    val showOverlayActionMenu = !isSelectionMode && columnsCount == 1

    Box {
        Box(
            modifier = modifier
                .fillMaxWidth()
                .then(
                    when {
                        isSelectionMode -> Modifier.clickable(onClick = onClick)
                        isCustomSortEditing -> Modifier
                        else -> Modifier.combinedClickable(
                            onClick = onClick,
                            onLongClick = onLongClick,
                        )
                    },
                ),
        ) {
            SubscriptionCardView(
                subscription = item.subscription,
                size = boardCardSize(columnsCount),
                contentEndInset = if (showOverlayActionMenu) boardCardActionInset(columnsCount) else 0.dp,
                pinnedIndicatorEndInset = if (showInlineActionMenu) boardCardPinnedInset(columnsCount) else 0.dp,
                showIcon = columnsCount != 3,
                showDateBelowLabel = columnsCount == 3,
                referenceMonth = referenceMonth,
                billingDateOverride = item.effectiveBillingDate,
                onTapIcon = if (isSelectionMode || isCustomSortEditing) null else onChangeIcon,
                trailingContent = if (showInlineActionMenu) {
                    {
                        BoardCardActionMenuButton(
                            expanded = menuExpanded,
                            strings = strings,
                            isCompact = true,
                            onExpandChange = { menuExpanded = it },
                            onEdit = onEdit,
                            onTogglePinned = onTogglePinned,
                            onChangeIcon = onChangeIcon,
                            onMarkPaymentComplete = onMarkPaymentComplete,
                            onCancelPaymentComplete = onCancelPaymentComplete,
                            onArchive = onArchive,
                            onDelete = onDelete,
                            isPinned = item.subscription.isPinned,
                        )
                    }
                } else {
                    null
                },
                modifier = Modifier.then(
                    if (isDropTarget) {
                        Modifier.border(
                            width = 2.dp,
                            color = ColorTokens.Accent.copy(alpha = 0.65f),
                            shape = PayBoardShapes.Card,
                        )
                    } else {
                        Modifier
                    },
                ),
            )
        }

        if (isSelectionMode) {
            Icon(
                imageVector = if (isSelected) Icons.Default.CheckCircle else Icons.Default.Circle,
                contentDescription = null,
                tint = if (isSelected) ColorTokens.Accent else payMutedColor(),
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(8.dp),
            )
        } else if (showOverlayActionMenu) {
            Box(
                modifier = Modifier
                    .align(Alignment.TopEnd)
                    .padding(6.dp),
            ) {
                BoardCardActionMenuButton(
                    expanded = menuExpanded,
                    strings = strings,
                    isCompact = false,
                    onExpandChange = { menuExpanded = it },
                    onEdit = onEdit,
                    onTogglePinned = onTogglePinned,
                    onChangeIcon = onChangeIcon,
                    onMarkPaymentComplete = onMarkPaymentComplete,
                    onCancelPaymentComplete = onCancelPaymentComplete,
                    onArchive = onArchive,
                    onDelete = onDelete,
                    isPinned = item.subscription.isPinned,
                )
            }
        }
    }
}

@Composable
private fun BoardCardActionMenuButton(
    expanded: Boolean,
    strings: PayBoardStrings,
    isCompact: Boolean,
    onExpandChange: (Boolean) -> Unit,
    onEdit: () -> Unit,
    onTogglePinned: () -> Unit,
    onChangeIcon: () -> Unit,
    onMarkPaymentComplete: () -> Unit,
    onCancelPaymentComplete: () -> Unit,
    onArchive: () -> Unit,
    onDelete: () -> Unit,
    isPinned: Boolean,
) {
    Box {
        IconButton(
            onClick = { onExpandChange(true) },
            modifier = Modifier.size(if (isCompact) 32.dp else 36.dp),
        ) {
            Icon(
                imageVector = Icons.Default.MoreHoriz,
                contentDescription = strings.cardActions,
            )
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { onExpandChange(false) },
        ) {
            DropdownMenuItem(
                text = { Text(strings.editSubscription) },
                onClick = {
                    onExpandChange(false)
                    onEdit()
                },
            )
            DropdownMenuItem(
                text = { Text(if (isPinned) strings.unpin else strings.pin) },
                onClick = {
                    onExpandChange(false)
                    onTogglePinned()
                },
            )
            DropdownMenuItem(
                text = { Text(strings.changeIcon) },
                onClick = {
                    onExpandChange(false)
                    onChangeIcon()
                },
            )
            DropdownMenuItem(
                text = { Text(strings.markAsPaid) },
                onClick = {
                    onExpandChange(false)
                    onMarkPaymentComplete()
                },
            )
            DropdownMenuItem(
                text = { Text(strings.cancelPayment) },
                onClick = {
                    onExpandChange(false)
                    onCancelPaymentComplete()
                },
            )
            DropdownMenuItem(
                text = { Text(strings.archive) },
                onClick = {
                    onExpandChange(false)
                    onArchive()
                },
            )
            DropdownMenuItem(
                text = { Text(strings.deleteSingle) },
                onClick = {
                    onExpandChange(false)
                    onDelete()
                },
            )
        }
    }
}

@Composable
private fun BoardDragPreviewCard(
    item: DisplayedSubscription,
    columnsCount: Int,
    referenceMonth: Instant,
) {
    SubscriptionCardView(
        subscription = item.subscription,
        size = boardCardSize(columnsCount),
        contentEndInset = boardCardActionInset(columnsCount),
        showIcon = columnsCount != 3,
        showDateBelowLabel = columnsCount == 3,
        referenceMonth = referenceMonth,
        billingDateOverride = item.effectiveBillingDate,
        onTapIcon = null,
        modifier = Modifier
            .fillMaxWidth()
            .graphicsLayer { alpha = 0.4f }
            .border(
                width = 2.dp,
                color = ColorTokens.Accent.copy(alpha = 0.55f),
                shape = PayBoardShapes.Card,
            ),
    )
}

@Composable
private fun BulkActionBar(
    selectedCount: Int,
    strings: PayBoardStrings,
    modifier: Modifier = Modifier,
    onChangeSelectedDate: () -> Unit,
    onCompleteSelected: () -> Unit,
    onCancelCompleteSelected: () -> Unit,
    onArchiveSelected: () -> Unit,
    onDeleteSelected: () -> Unit,
) {
    PayBoardPanel(modifier = modifier) {
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                text = strings.selectedCount(selectedCount),
                style = MaterialTheme.typography.bodyMedium,
                color = payMutedColor(),
            )
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                BulkActionButton(
                    icon = Icons.Default.DateRange,
                    label = strings.changeSelectedDate,
                    onClick = onChangeSelectedDate,
                )
                BulkActionButton(
                    icon = Icons.Default.DoneAll,
                    label = strings.markSelectedPaid,
                    onClick = onCompleteSelected,
                )
                BulkActionButton(
                    icon = Icons.Default.CheckCircle,
                    label = strings.cancelSelectedPayment,
                    onClick = onCancelCompleteSelected,
                )
                BulkActionButton(
                    icon = Icons.Default.Unarchive,
                    label = strings.archiveSelected,
                    onClick = onArchiveSelected,
                )
                BulkActionButton(
                    icon = Icons.Default.Delete,
                    label = strings.deleteSelected,
                    onClick = onDeleteSelected,
                    isDestructive = true,
                )
            }
        }
    }
}

@Composable
private fun BulkActionButton(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    onClick: () -> Unit,
    isDestructive: Boolean = false,
    enabled: Boolean = true,
) {
    val baseTint = if (isDestructive) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface
    val tint = if (enabled) baseTint else payMutedColor()
    Surface(
        modifier = Modifier.then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier),
        color = MaterialTheme.colorScheme.surface,
        shape = PayBoardShapes.Control,
        tonalElevation = 1.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = tint,
                modifier = Modifier.size(16.dp),
            )
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                color = tint,
            )
        }
    }
}

@Composable
private fun CalendarSection(
    strings: PayBoardStrings,
    displayedMonth: YearMonth,
    isMonthSelectorVisible: Boolean,
    calendarDays: List<CalendarDay>,
    calendarMarkerByDate: Map<LocalDate, CalendarMarker>,
    selectedDateSubscriptions: List<CalendarSelectedSubscription>,
    onToggleMonthSelector: () -> Unit,
    onMoveMonth: (Int) -> Unit,
    onMonthSelected: (YearMonth) -> Unit,
    onDateSelected: (LocalDate) -> Unit,
    onSubscriptionClick: (Subscription) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text(
            text = strings.routeCalendar,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
        )

        PayBoardPanel {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Surface(
                        modifier = Modifier.clickable(onClick = onToggleMonthSelector),
                        color = MaterialTheme.colorScheme.surface,
                        shape = PayBoardShapes.Control,
                        tonalElevation = 1.dp,
                    ) {
                        Row(
                            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            Text(
                                text = strings.monthYearTitle(displayedMonth),
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                            )
                            Icon(
                                imageVector = if (isMonthSelectorVisible) Icons.Default.ArrowDropUp else Icons.Default.ArrowDropDown,
                                contentDescription = null,
                            )
                        }
                    }

                    Spacer(modifier = Modifier.weight(1f))

                    SurfaceActionButton(onClick = { onMoveMonth(-1) }) {
                        Text(
                            text = "<",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                    SurfaceActionButton(onClick = { onMoveMonth(1) }) {
                        Text(
                            text = ">",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }

                if (isMonthSelectorVisible) {
                    InlineMonthSelector(
                        displayedMonth = displayedMonth,
                        strings = strings,
                        onMonthSelected = onMonthSelected,
                    )
                }

                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                    ) {
                        calendarWeekdayLabels(strings.locale).forEach { label ->
                            Text(
                                text = label,
                                modifier = Modifier.weight(1f),
                                style = MaterialTheme.typography.bodySmall,
                                fontWeight = FontWeight.SemiBold,
                                color = payMutedColor(),
                            )
                        }
                    }

                    calendarDays.chunked(7).forEach { week ->
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            week.forEach { day ->
                                CalendarDayCell(
                                    day = day,
                                    marker = calendarMarkerByDate[day.date],
                                    modifier = Modifier.weight(1f),
                                    onClick = { onDateSelected(day.date) },
                                )
                            }
                        }
                    }
                }
            }
        }

        if (selectedDateSubscriptions.isEmpty()) {
            Text(
                text = strings.calendarEmptyForDate,
                style = MaterialTheme.typography.bodyMedium,
                color = payMutedColor(),
            )
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                selectedDateSubscriptions.forEach { item ->
                    CalendarSubscriptionRow(
                        item = item,
                        strings = strings,
                        onClick = { onSubscriptionClick(item.subscription) },
                    )
                }
            }
        }
    }
}

@Composable
private fun CalendarDayCell(
    day: CalendarDay,
    marker: CalendarMarker?,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Box(
        modifier = modifier
            .clip(PayBoardShapes.Control)
            .clickable(onClick = onClick)
            .padding(vertical = 4.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp),
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(
                        if (day.isSelected) ColorTokens.Accent.copy(alpha = 0.22f) else androidx.compose.ui.graphics.Color.Transparent,
                    )
                    .border(
                        width = if (day.isToday && !day.isSelected) 1.5.dp else 0.dp,
                        color = if (day.isToday && !day.isSelected) ColorTokens.Accent.copy(alpha = 0.9f) else androidx.compose.ui.graphics.Color.Transparent,
                        shape = CircleShape,
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = day.date.dayOfMonth.toString(),
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = if (day.isToday) FontWeight.Bold else if (day.isSelected) FontWeight.SemiBold else FontWeight.Normal,
                    color = when {
                        day.isSelected -> ColorTokens.Accent
                        !day.isCurrentMonth -> payMutedColor().copy(alpha = 0.55f)
                        day.isToday -> ColorTokens.Accent
                        else -> MaterialTheme.colorScheme.onSurface
                    },
                )
            }
            Box(
                modifier = Modifier
                    .size(5.dp)
                    .clip(CircleShape)
                    .background(marker?.dotColor ?: androidx.compose.ui.graphics.Color.Transparent),
            )
        }
    }
}

@Composable
private fun CalendarSubscriptionRow(
    item: CalendarSelectedSubscription,
    strings: PayBoardStrings,
    onClick: () -> Unit,
) {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        color = MaterialTheme.colorScheme.surface,
        shape = PayBoardShapes.Control,
        tonalElevation = 1.dp,
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            PayBoardIconBadge(
                iconKey = item.subscription.iconKey,
                iconColorKey = item.subscription.iconColorKey,
                modifier = Modifier.size(32.dp),
            )
            Text(
                text = item.subscription.name,
                modifier = Modifier.weight(1f),
                style = MaterialTheme.typography.bodyMedium,
                maxLines = 1,
            )
            CalendarPaymentIndicator(isPaid = item.isPaid, strings = strings)
            Text(
                text = strings.formatCurrency(
                    amount = item.subscription.amount,
                    currencyCode = item.subscription.currencyCode,
                    isAmountUndecided = item.subscription.isAmountUndecided,
                ),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
            )
        }
    }
}

@Composable
private fun CalendarPaymentIndicator(
    isPaid: Boolean,
    strings: PayBoardStrings,
) {
    if (isPaid) {
        Surface(
            color = ColorTokens.Success.copy(alpha = 0.14f),
            shape = PayBoardShapes.Control,
        ) {
            Row(
                modifier = Modifier.padding(horizontal = 7.dp, vertical = 4.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(7.dp)
                        .clip(CircleShape)
                        .background(ColorTokens.Success),
                )
                Text(
                    text = strings.paymentDone,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = ColorTokens.Success,
                )
            }
        }
    } else {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(ColorTokens.Accent),
        )
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun SubscriptionEditorSheet(
    strings: PayBoardStrings,
    original: Subscription?,
    displayedMonth: YearMonth,
    onDismiss: () -> Unit,
    onConfirm: (Subscription) -> Unit,
) {
    val context = LocalContext.current
    var name by remember(original) { mutableStateOf(original?.name.orEmpty()) }
    var amountText by remember(original) { mutableStateOf(original?.amount?.stripTrailingZeros()?.toPlainString().orEmpty()) }
    var isAmountUndecided by remember(original) { mutableStateOf(original?.isAmountUndecided ?: false) }
    var category by remember(original) { mutableStateOf(original?.category ?: SubscriptionCategory.OTHER) }
    var customCategoryName by remember(original) { mutableStateOf(original?.customCategoryName.orEmpty()) }
    var nextBillingDateText by remember(original, displayedMonth) {
        mutableStateOf(original?.nextBillingDate?.toLocalDate()?.toString() ?: displayedMonth.atDay(1).toString())
    }
    var billingCycle by remember(original) { mutableStateOf(original?.billingCycle ?: BillingCycle.Monthly) }
    var notificationsEnabled by remember(original) { mutableStateOf(original?.notificationsEnabled ?: true) }
    var isPinned by remember(original) { mutableStateOf(original?.isPinned ?: false) }
    var isAutoPayEnabled by remember(original) { mutableStateOf(original?.isAutoPayEnabled ?: false) }
    var memo by remember(original) { mutableStateOf(original?.memo.orEmpty()) }
    var selectedIconKey by remember(original) { mutableStateOf(original?.iconKey.orEmpty()) }
    var selectedIconColorKey by remember(original) { mutableStateOf(original?.iconColorKey ?: "blue") }
    var isIconSheetVisible by remember { mutableStateOf(false) }
    var iconQuery by remember { mutableStateOf("") }
    var validationMessage by remember { mutableStateOf<String?>(null) }
    var categoryMenuExpanded by remember { mutableStateOf(false) }
    var billingCycleMenuExpanded by remember { mutableStateOf(false) }

    val openDatePicker = {
        val initialDate = strings.parseIsoLocalDate(nextBillingDateText) ?: displayedMonth.atDay(1)
        DatePickerDialog(
            context,
            { _, year, month, dayOfMonth ->
                nextBillingDateText = LocalDate.of(year, month + 1, dayOfMonth).toString()
                validationMessage = null
            },
            initialDate.year,
            initialDate.monthValue - 1,
            initialDate.dayOfMonth,
        ).show()
    }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) { Text(strings.cancel) }
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = if (original == null) strings.addSubscription else strings.editSubscription,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.weight(1f))
                TextButton(
                    onClick = {
                        val parsedAmount = amountText.toBigDecimalOrNull()
                        val parsedDate = strings.parseIsoLocalDate(nextBillingDateText)
                        if (
                            name.isBlank() ||
                            parsedDate == null ||
                            (!isAmountUndecided && parsedAmount == null) ||
                            (category == SubscriptionCategory.OTHER && customCategoryName.isBlank())
                        ) {
                            validationMessage = strings.invalidForm
                            return@TextButton
                        }

                        val base = original ?: Subscription(
                            id = UUID.randomUUID(),
                            name = name.trim(),
                            category = category,
                            amount = parsedAmount ?: BigDecimal.ZERO,
                            isAmountUndecided = isAmountUndecided,
                            billingCycle = billingCycle,
                            nextBillingDate = parsedDate.toInstantAtStartOfDay(),
                            iconKey = selectedIconKey.ifBlank { name.trim().take(1).uppercase().ifBlank { "?" } },
                            iconColorKey = selectedIconColorKey,
                        )
                        onConfirm(
                            base.copy(
                                name = name.trim(),
                                category = category,
                                amount = parsedAmount ?: BigDecimal.ZERO,
                                isAmountUndecided = isAmountUndecided,
                                billingCycle = billingCycle,
                                nextBillingDate = parsedDate.toInstantAtStartOfDay(),
                                iconKey = selectedIconKey.ifBlank {
                                    base.iconKey.takeIf { it.isNotBlank() }
                                        ?: name.trim().take(1).uppercase().ifBlank { "?" }
                                },
                                iconColorKey = selectedIconColorKey,
                                customCategoryName = customCategoryName.trim().ifBlank { null },
                                notificationsEnabled = notificationsEnabled,
                                isAutoPayEnabled = isAutoPayEnabled,
                                isPinned = isPinned,
                                memo = memo.trim().ifBlank { null },
                                updatedAt = Instant.now(),
                            ),
                        )
                    },
                ) { Text(strings.save) }
            }

            OutlinedTextField(
                value = name,
                onValueChange = {
                    name = it
                    validationMessage = null
                },
                label = { Text(strings.name) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )

            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable {
                        iconQuery = ""
                        isIconSheetVisible = true
                    },
                color = MaterialTheme.colorScheme.surface,
                shape = PayBoardShapes.Control,
                tonalElevation = 1.dp,
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    PayBoardIconBadge(
                        iconKey = selectedIconKey.ifBlank { name.trim().take(1).uppercase().ifBlank { "?" } },
                        iconColorKey = selectedIconColorKey,
                        modifier = Modifier.size(36.dp),
                    )
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = strings.changeIcon,
                            style = MaterialTheme.typography.bodySmall,
                            color = payMutedColor(),
                        )
                        Text(
                            text = PresetIconCatalog.iconFor(selectedIconKey)?.displayName ?: strings.select,
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                    Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                }
            }

            OutlinedTextField(
                value = amountText,
                onValueChange = {
                    amountText = it.filter(Char::isDigit)
                    validationMessage = null
                },
                label = { Text(strings.amount) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
                enabled = !isAmountUndecided,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(strings.amountUndecided)
                Spacer(modifier = Modifier.weight(1f))
                Switch(
                    checked = isAmountUndecided,
                    onCheckedChange = {
                        isAmountUndecided = it
                        if (it) amountText = ""
                    },
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = strings.category,
                    style = MaterialTheme.typography.bodySmall,
                    color = payMutedColor(),
                )
                Box {
                    Surface(
                        modifier = Modifier.clickable { categoryMenuExpanded = true },
                        color = MaterialTheme.colorScheme.surface,
                        shape = PayBoardShapes.Control,
                        tonalElevation = 1.dp,
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(strings.categoryLabel(category))
                            Spacer(modifier = Modifier.weight(1f))
                            Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                        }
                    }
                    DropdownMenu(
                        expanded = categoryMenuExpanded,
                        onDismissRequest = { categoryMenuExpanded = false },
                    ) {
                        SubscriptionCategory.entries.forEach { item ->
                            DropdownMenuItem(
                                text = { Text(strings.categoryLabel(item)) },
                                onClick = {
                                    category = item
                                    categoryMenuExpanded = false
                                },
                            )
                        }
                    }
                }
            }

            if (category == SubscriptionCategory.OTHER) {
                OutlinedTextField(
                    value = customCategoryName,
                    onValueChange = {
                        customCategoryName = it
                        validationMessage = null
                    },
                    label = { Text(strings.customCategory) },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true,
                )
            }

            Surface(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable(onClick = openDatePicker),
                color = MaterialTheme.colorScheme.surface,
                shape = PayBoardShapes.Control,
                tonalElevation = 1.dp,
            ) {
                Row(
                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 14.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                ) {
                    Icon(Icons.Default.DateRange, contentDescription = strings.openCalendar)
                    Column {
                        Text(
                            text = strings.nextBillingDateLabel,
                            style = MaterialTheme.typography.bodySmall,
                            color = payMutedColor(),
                        )
                        Text(
                            text = strings.parseIsoLocalDate(nextBillingDateText)?.let { strings.formatDate(it.toInstantAtStartOfDay()) }
                                ?: nextBillingDateText,
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = strings.billingCycle,
                    style = MaterialTheme.typography.bodySmall,
                    color = payMutedColor(),
                )
                Box {
                    Surface(
                        modifier = Modifier.clickable { billingCycleMenuExpanded = true },
                        color = MaterialTheme.colorScheme.surface,
                        shape = PayBoardShapes.Control,
                        tonalElevation = 1.dp,
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 14.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(strings.billingCycleLabel(billingCycle))
                            Spacer(modifier = Modifier.weight(1f))
                            Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                        }
                    }
                    DropdownMenu(
                        expanded = billingCycleMenuExpanded,
                        onDismissRequest = { billingCycleMenuExpanded = false },
                    ) {
                        listOf(BillingCycle.Monthly, BillingCycle.Yearly, BillingCycle.CustomDays(30)).forEach { item ->
                            DropdownMenuItem(
                                text = { Text(strings.billingCycleLabel(item)) },
                                onClick = {
                                    billingCycle = item
                                    billingCycleMenuExpanded = false
                                },
                            )
                        }
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(strings.notificationsEnabled)
                Spacer(modifier = Modifier.weight(1f))
                Switch(checked = notificationsEnabled, onCheckedChange = { notificationsEnabled = it })
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(strings.autoPayEnabled)
                Spacer(modifier = Modifier.weight(1f))
                Switch(checked = isAutoPayEnabled, onCheckedChange = { isAutoPayEnabled = it })
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(strings.pinned)
                Spacer(modifier = Modifier.weight(1f))
                Switch(checked = isPinned, onCheckedChange = { isPinned = it })
            }

            OutlinedTextField(
                value = memo,
                onValueChange = { memo = it },
                label = { Text(strings.memo) },
                modifier = Modifier.fillMaxWidth(),
                minLines = 3,
            )

            validationMessage?.let { message ->
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error,
                )
            }
        }
    }

    if (isIconSheetVisible) {
        QuickIconSheet(
            strings = strings,
            query = iconQuery,
            onQueryChange = { iconQuery = it },
            onDismiss = { isIconSheetVisible = false },
            onSelect = { icon ->
                selectedIconKey = icon.key
                selectedIconColorKey = icon.colorKey
                isIconSheetVisible = false
                iconQuery = ""
            },
        )
    }
}

@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun QuickIconSheet(
    strings: PayBoardStrings,
    query: String,
    onQueryChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onSelect: (PresetIcon) -> Unit,
) {
    val presets = remember(query) { PresetIconCatalog.search(query) }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onDismiss) {
                    Text(strings.cancel)
                }
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = strings.changeIcon,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.weight(1f))
            }

            OutlinedTextField(
                value = query,
                onValueChange = onQueryChange,
                label = { Text(strings.iconSearch) },
                modifier = Modifier.fillMaxWidth(),
                singleLine = true,
            )

            presets.forEach { preset ->
                Surface(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onSelect(preset) },
                    color = MaterialTheme.colorScheme.surface,
                    shape = PayBoardShapes.Control,
                    tonalElevation = 1.dp,
                ) {
                    Row(
                        modifier = Modifier.padding(horizontal = 14.dp, vertical = 14.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        PayBoardIconBadge(
                            iconKey = preset.key,
                            iconColorKey = preset.colorKey,
                            modifier = Modifier.size(34.dp),
                        )
                        Text(
                            text = preset.displayName,
                            style = MaterialTheme.typography.bodyLarge,
                        )
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class, androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
private fun CustomSortSheet(
    strings: PayBoardStrings,
    subscriptions: List<Subscription>,
    title: String,
    description: String,
    onDismiss: () -> Unit,
    onSave: (List<UUID>) -> Unit,
) {
    val orderedSubscriptions = remember(subscriptions) {
        mutableStateListOf<Subscription>().apply { addAll(subscriptions) }
    }
    val density = LocalDensity.current
    val view = LocalView.current
    val swapThresholdPx = remember(density) { with(density) { 28.dp.toPx() } }
    var draggedId by remember { mutableStateOf<UUID?>(null) }
    var dragOffsetY by remember { mutableFloatStateOf(0f) }

    fun persistAndDismiss() {
        onSave(orderedSubscriptions.map(Subscription::id))
        onDismiss()
    }

    ModalBottomSheet(
        onDismissRequest = ::persistAndDismiss,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = ::persistAndDismiss) {
                    Text(strings.doneCustomOrder)
                }
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.SemiBold,
                )
                Spacer(modifier = Modifier.weight(1f))
            }

            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = payMutedColor(),
            )

            LazyColumn(
                modifier = Modifier.heightIn(max = 520.dp),
                userScrollEnabled = draggedId == null,
                verticalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(
                    items = orderedSubscriptions,
                    key = { it.id },
                ) { subscription ->
                    val isDragging = draggedId == subscription.id
                    Surface(
                        modifier = Modifier
                            .fillMaxWidth()
                            .zIndex(if (isDragging) 1f else 0f)
                            .graphicsLayer {
                                translationY = if (isDragging) dragOffsetY else 0f
                            }
                            .pointerInput(subscription.id) {
                                detectDragGesturesAfterLongPress(
                                    onDragStart = {
                                        draggedId = subscription.id
                                        dragOffsetY = 0f
                                        view.performHapticFeedback(HapticFeedbackConstants.LONG_PRESS)
                                    },
                                    onDragEnd = {
                                        draggedId = null
                                        dragOffsetY = 0f
                                        onSave(orderedSubscriptions.map(Subscription::id))
                                        view.performHapticFeedback(HapticFeedbackConstants.KEYBOARD_TAP)
                                    },
                                    onDragCancel = {
                                        draggedId = null
                                        dragOffsetY = 0f
                                        onSave(orderedSubscriptions.map(Subscription::id))
                                    },
                                    onDrag = { change, dragAmount ->
                                        if (draggedId != subscription.id) {
                                            return@detectDragGesturesAfterLongPress
                                        }
                                        change.consume()
                                        dragOffsetY += dragAmount.y
                                        while (dragOffsetY > swapThresholdPx) {
                                            val currentIndex = orderedSubscriptions.indexOfFirst { it.id == subscription.id }
                                            if (currentIndex == -1 || currentIndex >= orderedSubscriptions.lastIndex) {
                                                break
                                            }
                                            orderedSubscriptions.move(currentIndex, currentIndex + 1)
                                            dragOffsetY -= swapThresholdPx
                                            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                                        }
                                        while (dragOffsetY < -swapThresholdPx) {
                                            val currentIndex = orderedSubscriptions.indexOfFirst { it.id == subscription.id }
                                            if (currentIndex <= 0) {
                                                break
                                            }
                                            orderedSubscriptions.move(currentIndex, currentIndex - 1)
                                            dragOffsetY += swapThresholdPx
                                            view.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
                                        }
                                    },
                                )
                            },
                        color = MaterialTheme.colorScheme.surface,
                        shape = PayBoardShapes.Card,
                        tonalElevation = if (isDragging) 4.dp else 1.dp,
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 14.dp, vertical = 12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            PayBoardIconBadge(
                                iconKey = subscription.iconKey,
                                iconColorKey = subscription.iconColorKey,
                                modifier = Modifier.size(36.dp),
                            )
                            Column(
                                modifier = Modifier.weight(1f),
                                verticalArrangement = Arrangement.spacedBy(2.dp),
                            ) {
                                Text(
                                    text = subscription.name,
                                    style = MaterialTheme.typography.bodyLarge,
                                    fontWeight = FontWeight.SemiBold,
                                    maxLines = 1,
                                )
                                Text(
                                    text = "${strings.formatCurrency(subscription.amount, subscription.currencyCode, subscription.isAmountUndecided)} · ${strings.formatShortDate(subscription.nextBillingDate)}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = payMutedColor(),
                                    maxLines = 1,
                                )
                            }
                            if (subscription.isPinned) {
                                Box(
                                    modifier = Modifier
                                        .size(8.dp)
                                        .clip(CircleShape)
                                        .background(ColorTokens.Accent),
                                )
                            }
                            Icon(
                                imageVector = Icons.Default.DragIndicator,
                                contentDescription = strings.editCustomOrder,
                                tint = payMutedColor(),
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EmptyState(strings: PayBoardStrings) {
    PayBoardPanel {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Text(strings.noSubscriptionsYet, style = MaterialTheme.typography.titleMedium)
            Text(
                strings.boardEmptyCaption,
                style = MaterialTheme.typography.bodyMedium,
                color = payMutedColor(),
            )
        }
    }
}

@Composable
private fun payMutedColor() = if (MaterialTheme.colorScheme.background.luminance() > 0.5f) {
    ColorTokens.MutedLight
} else {
    ColorTokens.MutedDark
}

private data class DisplayedSubscription(
    val subscription: Subscription,
    val effectiveBillingDate: Instant,
    val isPaidInDisplayedMonth: Boolean,
)

private data class CalendarDay(
    val date: LocalDate,
    val isCurrentMonth: Boolean,
    val isSelected: Boolean,
    val isToday: Boolean,
)

private data class CalendarSelectedSubscription(
    val subscription: Subscription,
    val isPaid: Boolean,
)

private enum class CalendarMarker(
    val dotColor: androidx.compose.ui.graphics.Color,
    val priority: Int,
) {
    SCHEDULED(ColorTokens.Accent.copy(alpha = 0.85f), 0),
    WARNING(androidx.compose.ui.graphics.Color(0xFFF4B400), 1),
    CRITICAL(ColorTokens.Danger, 2),
    PAID(ColorTokens.Success, 3),
}

private sealed interface EditorSheet {
    data class Create(val token: UUID) : EditorSheet

    data class Edit(val subscription: Subscription) : EditorSheet
}

private fun buildBoardSubscriptions(
    subscriptions: List<Subscription>,
    query: String,
    filter: BoardFilter,
    displayedMonth: YearMonth,
    selectedSort: BoardSortOption,
    customSortOrderIds: List<UUID>,
): List<DisplayedSubscription> {
    val monthSubscriptions = buildMonthSubscriptions(subscriptions, displayedMonth)
    val trimmedQuery = query.trim()
    val customOrderMap = customSortOrderIds.withIndex().associate { it.value to it.index }

    return monthSubscriptions
        .filter { item -> item.matches(filter) }
        .filter { item ->
            if (trimmedQuery.isBlank()) {
                true
            } else {
                item.subscription.matchesQuery(trimmedQuery)
            }
        }
        .sortedWith { lhs, rhs ->
            if (lhs.subscription.isPinned != rhs.subscription.isPinned) {
                return@sortedWith if (lhs.subscription.isPinned) -1 else 1
            }
            when (selectedSort) {
                BoardSortOption.NEXT_BILLING_ASC -> lhs.effectiveBillingDate.compareTo(rhs.effectiveBillingDate)
                BoardSortOption.NEXT_BILLING_DESC -> rhs.effectiveBillingDate.compareTo(lhs.effectiveBillingDate)
                BoardSortOption.NAME_ASC -> lhs.subscription.name.lowercase().compareTo(rhs.subscription.name.lowercase())
                BoardSortOption.AMOUNT_DESC -> rhs.subscription.amount.compareTo(lhs.subscription.amount)
                BoardSortOption.CUSTOM -> {
                    val leftOrder = customOrderMap[lhs.subscription.id] ?: Int.MAX_VALUE
                    val rightOrder = customOrderMap[rhs.subscription.id] ?: Int.MAX_VALUE
                    if (leftOrder == rightOrder) {
                        lhs.subscription.createdAt.compareTo(rhs.subscription.createdAt)
                    } else {
                        leftOrder.compareTo(rightOrder)
                    }
                }
            }
        }
}

private fun buildCustomOrderedSubscriptions(
    subscriptions: List<Subscription>,
    customSortOrderIds: List<UUID>,
): List<Subscription> {
    val customOrderMap = syncCustomSortOrder(customSortOrderIds, subscriptions.map(Subscription::id))
        .withIndex()
        .associate { it.value to it.index }
    return subscriptions.sortedWith(
        compareByDescending<Subscription> { it.isPinned }
            .thenBy { customOrderMap[it.id] ?: Int.MAX_VALUE }
            .thenBy { it.name.lowercase() },
    )
}

private fun buildMonthSubscriptions(
    subscriptions: List<Subscription>,
    displayedMonth: YearMonth,
): List<DisplayedSubscription> = subscriptions.mapNotNull { subscription ->
    val projectedDate = projectedBillingDateInDisplayedMonth(subscription, displayedMonth)
    val paidInDisplayedMonth = subscription.isPaidInMonth(displayedMonth)
    if (projectedDate == null && !paidInDisplayedMonth) {
        null
    } else {
        DisplayedSubscription(
            subscription = subscription,
            effectiveBillingDate = projectedDate ?: subscription.nextBillingDate,
            isPaidInDisplayedMonth = paidInDisplayedMonth,
        )
    }
}

private fun buildSelectedDateSubscriptions(
    subscriptions: List<Subscription>,
    displayedMonth: YearMonth,
    selectedDate: LocalDate,
): List<CalendarSelectedSubscription> = subscriptions.mapNotNull { subscription ->
    val paidOnSelectedDate = paymentHistoryDates(subscription).any { it.toLocalDate() == selectedDate }
    val projectedDate = projectedBillingDateInDisplayedMonth(subscription, displayedMonth)?.toLocalDate()
    when {
        paidOnSelectedDate -> CalendarSelectedSubscription(subscription = subscription, isPaid = true)
        projectedDate == selectedDate -> CalendarSelectedSubscription(subscription = subscription, isPaid = false)
        else -> null
    }
}.sortedWith(
    compareByDescending<CalendarSelectedSubscription> { it.subscription.isPinned }
        .thenBy { it.subscription.name.lowercase() },
)

private fun buildCalendarDays(
    displayedMonth: YearMonth,
    selectedDate: LocalDate,
    locale: java.util.Locale,
): List<CalendarDay> {
    val firstDayOfMonth = displayedMonth.atDay(1)
    val daysInMonth = displayedMonth.lengthOfMonth()
    val firstDayOfWeek = WeekFields.of(locale).firstDayOfWeek
    val leadingCount = (firstDayOfMonth.dayOfWeek.value - firstDayOfWeek.value + 7) % 7
    val items = mutableListOf<CalendarDay>()

    for (offset in leadingCount downTo 1) {
        val date = firstDayOfMonth.minusDays(offset.toLong())
        items += date.toCalendarDay(selectedDate, isCurrentMonth = false)
    }

    for (day in 1..daysInMonth) {
        val date = displayedMonth.atDay(day)
        items += date.toCalendarDay(selectedDate, isCurrentMonth = true)
    }

    val trailingCount = (7 - (items.size % 7)) % 7
    if (trailingCount > 0) {
        val lastDate = items.last().date
        for (offset in 1..trailingCount) {
            val date = lastDate.plusDays(offset.toLong())
            items += date.toCalendarDay(selectedDate, isCurrentMonth = false)
        }
    }

    return items
}

private fun buildCalendarMarkerByDate(
    subscriptions: List<Subscription>,
    displayedMonth: YearMonth,
): Map<LocalDate, CalendarMarker> {
    val result = linkedMapOf<LocalDate, CalendarMarker>()

    buildMonthSubscriptions(subscriptions, displayedMonth).forEach { item ->
        val date = item.effectiveBillingDate.toLocalDate()
        val nextMarker = when (billingUrgency(item.effectiveBillingDate)) {
            BillingUrgency.WARNING -> CalendarMarker.WARNING
            BillingUrgency.CRITICAL -> CalendarMarker.CRITICAL
            null -> CalendarMarker.SCHEDULED
        }
        val existing = result[date]
        if (existing == null || existing.priority < nextMarker.priority) {
            result[date] = nextMarker
        }
    }

    subscriptions.forEach { subscription ->
        paymentHistoryDates(subscription)
            .map(Instant::toLocalDate)
            .filter { YearMonth.from(it) == displayedMonth }
            .forEach { date ->
                val existing = result[date]
                if (existing == null || existing.priority < CalendarMarker.PAID.priority) {
                    result[date] = CalendarMarker.PAID
                }
            }
    }

    return result
}

private fun calendarWeekdayLabels(locale: java.util.Locale): List<String> {
    val firstDayOfWeek = WeekFields.of(locale).firstDayOfWeek
    return (0..6).map { offset ->
        val day = DayOfWeek.of(((firstDayOfWeek.value - 1 + offset) % 7) + 1)
        day.getDisplayName(TextStyle.SHORT, locale)
    }
}

private fun paymentHistoryDates(subscription: Subscription): List<Instant> = when {
    subscription.paymentHistoryDates.isNotEmpty() -> subscription.paymentHistoryDates
    subscription.lastPaymentDate != null -> listOfNotNull(subscription.lastPaymentDate)
    else -> emptyList()
}

private fun billingUrgency(billingDate: Instant): BillingUrgency? {
    val today = LocalDate.now()
    val targetDate = billingDate.toLocalDate()
    val days = ChronoUnit.DAYS.between(today, targetDate)
    return when {
        days <= 1 -> BillingUrgency.CRITICAL
        days <= 3 -> BillingUrgency.WARNING
        else -> null
    }
}

private fun DisplayedSubscription.matches(filter: BoardFilter): Boolean {
    val today = LocalDate.now()
    val billingDate = effectiveBillingDate.toLocalDate()
    return when (filter) {
        BoardFilter.ALL -> true
        BoardFilter.THIS_WEEK -> !billingDate.isBefore(today) && !billingDate.isAfter(today.plusDays(7))
        BoardFilter.THIS_MONTH -> true
    }
}

private fun Subscription.matchesQuery(query: String): Boolean {
    val normalizedQuery = query.lowercase()
    return name.lowercase().contains(normalizedQuery) ||
        category.label.lowercase().contains(normalizedQuery) ||
        customCategoryName.orEmpty().lowercase().contains(normalizedQuery)
}

private fun Subscription.isPaidInMonth(displayedMonth: YearMonth): Boolean =
    lastPaymentDate?.isInYearMonth(displayedMonth) == true ||
        paymentHistoryDates.any { it.isInYearMonth(displayedMonth) }

private fun projectedBillingDateInDisplayedMonth(
    subscription: Subscription,
    displayedMonth: YearMonth,
): Instant? {
    val monthStart = displayedMonth.atDay(1)
    val monthEnd = displayedMonth.plusMonths(1).atDay(1)
    val anchor = subscription.nextBillingDate.toLocalDate()

    if (!anchor.isBefore(monthStart) && anchor.isBefore(monthEnd)) {
        return anchor.toInstantAtStartOfDay()
    }

    return when (val cycle = subscription.billingCycle) {
        BillingCycle.Monthly -> {
            val projectedDay = anchor.dayOfMonth.coerceAtMost(displayedMonth.lengthOfMonth())
            LocalDate.of(displayedMonth.year, displayedMonth.month, projectedDay).toInstantAtStartOfDay()
        }
        BillingCycle.Yearly -> {
            if (anchor.month != displayedMonth.month) {
                null
            } else {
                val projectedDay = anchor.dayOfMonth.coerceAtMost(displayedMonth.lengthOfMonth())
                LocalDate.of(displayedMonth.year, displayedMonth.month, projectedDay).toInstantAtStartOfDay()
            }
        }
        is BillingCycle.CustomDays -> {
            val interval = cycle.days.coerceAtLeast(1).toLong()
            val deltaDays = ChronoUnit.DAYS.between(anchor, monthStart)
            var multiplier = kotlin.math.floor(deltaDays.toDouble() / interval.toDouble()).toLong()
            var candidate = anchor.plusDays(multiplier * interval)
            while (candidate.isBefore(monthStart)) {
                multiplier += 1
                candidate = anchor.plusDays(multiplier * interval)
            }
            if (!candidate.isBefore(monthStart) && candidate.isBefore(monthEnd)) {
                candidate.toInstantAtStartOfDay()
            } else {
                null
            }
        }
    }
}

private fun Instant.isInYearMonth(yearMonth: YearMonth): Boolean = YearMonth.from(toLocalDate()) == yearMonth

private fun Instant.toLocalDate(): LocalDate = atZone(ZoneId.systemDefault()).toLocalDate()

private fun LocalDate.toInstantAtStartOfDay(): Instant = atStartOfDay(ZoneId.systemDefault()).toInstant()

private fun LocalDate.toCalendarDay(
    selectedDate: LocalDate,
    isCurrentMonth: Boolean,
): CalendarDay = CalendarDay(
    date = this,
    isCurrentMonth = isCurrentMonth,
    isSelected = this == selectedDate,
    isToday = this == LocalDate.now(),
)

private fun buildMonthOptions(start: YearMonth, end: YearMonth): List<YearMonth> {
    val months = mutableListOf<YearMonth>()
    var cursor = start
    while (cursor <= end) {
        months += cursor
        cursor = cursor.plusMonths(1)
    }
    return months
}

private fun minYearMonth(lhs: YearMonth, rhs: YearMonth): YearMonth = if (lhs <= rhs) lhs else rhs

private fun maxYearMonth(lhs: YearMonth, rhs: YearMonth): YearMonth = if (lhs >= rhs) lhs else rhs

private fun loadCustomSortOrder(prefs: android.content.SharedPreferences): List<UUID> =
    prefs.getString("board.customSortOrder", "")
        .orEmpty()
        .split(",")
        .mapNotNull { raw ->
            raw.takeIf(String::isNotBlank)?.let { value ->
                runCatching { UUID.fromString(value) }.getOrNull()
            }
        }

private fun saveCustomSortOrder(
    prefs: android.content.SharedPreferences,
    ids: List<UUID>,
) {
    prefs.edit().putString("board.customSortOrder", ids.joinToString(",")).apply()
}

private fun PayBoardStrings.boardSortLabel(option: BoardSortOption): String = when (option) {
    BoardSortOption.NEXT_BILLING_ASC -> sortNextBillingAsc
    BoardSortOption.NEXT_BILLING_DESC -> sortNextBillingDesc
    BoardSortOption.NAME_ASC -> sortNameAsc
    BoardSortOption.AMOUNT_DESC -> sortAmountDesc
    BoardSortOption.CUSTOM -> sortCustom
}

private fun syncCustomSortOrder(
    current: List<UUID>,
    visibleIds: List<UUID>,
): List<UUID> {
    val visibleSet = visibleIds.toSet()
    val next = current.filter { it in visibleSet }.toMutableList()
    visibleIds.forEach { id ->
        if (id !in next) {
            next += id
        }
    }
    return next
}

private fun previewBoardDragStep(
    offsetX: Float,
    offsetY: Float,
    columnsCount: Int,
    horizontalStepPx: Float,
    verticalStepPx: Float,
): Int {
    val normalizedX = offsetX / horizontalStepPx.coerceAtLeast(1f)
    val normalizedY = offsetY / verticalStepPx.coerceAtLeast(1f)
    val dominant = maxOf(abs(normalizedX), abs(normalizedY))
    if (dominant < 0.45f) return 0
    return if (abs(normalizedY) > abs(normalizedX)) {
        normalizedY.roundToInt() * columnsCount.coerceAtLeast(1)
    } else {
        normalizedX.roundToInt()
    }
}

private fun previewDropTargetId(
    visibleOrder: List<UUID>,
    selectedIds: Set<UUID>,
    anchorId: UUID,
    step: Int,
): UUID? {
    if (step == 0) return null
    val movingIds = if (anchorId in selectedIds) {
        visibleOrder.filter { it in selectedIds }
    } else {
        listOf(anchorId)
    }
    if (movingIds.isEmpty()) return null
    val currentStart = visibleOrder.indexOfFirst { it in movingIds }
    val currentEnd = visibleOrder.indexOfLast { it in movingIds }
    if (currentStart == -1 || currentEnd == -1) return null
    val targetIndex = if (step > 0) {
        (currentEnd + step).coerceAtMost(visibleOrder.lastIndex)
    } else {
        (currentStart + step).coerceAtLeast(0)
    }
    return visibleOrder.getOrNull(targetIndex)?.takeIf { it !in movingIds }
}

private fun previewBoardDragPlacement(
    boardSubscriptions: List<DisplayedSubscription>,
    selectedIds: Set<UUID>,
    anchorId: UUID,
    step: Int,
): BoardPreviewPlacement? {
    if (step == 0) return null
    val visibleOrder = boardSubscriptions.map { it.subscription.id }
    if (anchorId !in visibleOrder) return null
    val movingIds = if (anchorId in selectedIds) {
        visibleOrder.filter { it in selectedIds }
    } else {
        listOf(anchorId)
    }
    if (movingIds.isEmpty()) return null
    val currentStart = visibleOrder.indexOfFirst { it in movingIds }
    if (currentStart == -1) return null
    val targetStart = (currentStart + step).coerceIn(0, visibleOrder.size - movingIds.size)
    if (targetStart == currentStart) return null
    val previewItems = movingIds.mapNotNull { id ->
        boardSubscriptions.firstOrNull { it.subscription.id == id }
    }
    if (previewItems.isEmpty()) return null
    val insertionIndex = if (targetStart > currentStart) {
        targetStart + movingIds.size
    } else {
        targetStart
    }.coerceIn(0, boardSubscriptions.size)
    return BoardPreviewPlacement(
        movingIds = movingIds,
        insertionIndex = insertionIndex,
        previewItems = previewItems,
    )
}

private fun buildBoardGridEntries(
    boardSubscriptions: List<DisplayedSubscription>,
    previewPlacement: BoardPreviewPlacement?,
): List<BoardGridEntry> {
    if (previewPlacement == null) {
        return boardSubscriptions.map { item ->
            BoardGridEntry(
                key = item.subscription.id.toString(),
                item = item,
            )
        }
    }

    val entries = mutableListOf<BoardGridEntry>()
    boardSubscriptions.forEachIndexed { index, item ->
        if (index == previewPlacement.insertionIndex) {
            previewPlacement.previewItems.forEach { previewItem ->
                entries += BoardGridEntry(
                    key = "preview-${previewItem.subscription.id}-$index",
                    previewItem = previewItem,
                )
            }
        }
        entries += BoardGridEntry(
            key = item.subscription.id.toString(),
            item = item,
        )
    }
    if (previewPlacement.insertionIndex == boardSubscriptions.size) {
        previewPlacement.previewItems.forEach { previewItem ->
            entries += BoardGridEntry(
                key = "preview-${previewItem.subscription.id}-end",
                previewItem = previewItem,
            )
        }
    }
    return entries
}

private fun reorderVisibleSelection(
    visibleOrder: List<UUID>,
    selectedIds: Set<UUID>,
    anchorId: UUID,
    step: Int,
): List<UUID> {
    if (anchorId !in visibleOrder || step == 0) return visibleOrder
    val movingIds = if (anchorId in selectedIds) {
        visibleOrder.filter { it in selectedIds }
    } else {
        listOf(anchorId)
    }
    if (movingIds.isEmpty() || movingIds.size == visibleOrder.size) return visibleOrder

    val currentStart = visibleOrder.indexOfFirst { it in movingIds }
    if (currentStart == -1) return visibleOrder
    val targetStart = (currentStart + step).coerceIn(0, visibleOrder.size - movingIds.size)
    if (targetStart == currentStart) return visibleOrder

    val remaining = visibleOrder.filterNot { it in movingIds }.toMutableList()
    val insertionIndex = visibleOrder
        .take(targetStart)
        .count { it !in movingIds }
        .coerceIn(0, remaining.size)
    remaining.addAll(insertionIndex, movingIds)
    return remaining
}

private fun mergeVisibleOrder(
    fullOrder: List<UUID>,
    visibleIds: Set<UUID>,
    reorderedVisibleIds: List<UUID>,
): List<UUID> {
    val visibleIterator = reorderedVisibleIds.iterator()
    return fullOrder.map { id ->
        if (id in visibleIds && visibleIterator.hasNext()) {
            visibleIterator.next()
        } else {
            id
        }
    }
}

private fun reorderVisibleOrder(
    visibleOrder: List<UUID>,
    draggedId: UUID,
    targetIndex: Int,
    selectedIds: Set<UUID>,
    isSelectionMode: Boolean,
): List<UUID> {
    val targetId = visibleOrder.getOrNull(targetIndex) ?: return visibleOrder
    if (draggedId !in visibleOrder || draggedId == targetId) return visibleOrder

    if (isSelectionMode && draggedId in selectedIds && selectedIds.size > 1) {
        if (targetId in selectedIds) return visibleOrder
        val movingBlock = visibleOrder.filter { it in selectedIds }
        if (movingBlock.isEmpty() || movingBlock.size == visibleOrder.size) return visibleOrder

        val remaining = visibleOrder.filterNot { it in selectedIds }.toMutableList()
        val insertionIndex = remaining.indexOf(targetId)
        if (insertionIndex == -1) return visibleOrder
        remaining.addAll(insertionIndex, movingBlock)
        return remaining
    }

    val reordered = visibleOrder.toMutableList()
    reordered.move(reordered.indexOf(draggedId), targetIndex)
    return reordered
}

private fun <T> MutableList<T>.move(fromIndex: Int, toIndex: Int) {
    if (fromIndex == toIndex) return
    val item = removeAt(fromIndex)
    add(toIndex, item)
}

private fun boardCardSize(columnsCount: Int): SubscriptionCardSize = when (columnsCount.coerceIn(1, 3)) {
    3 -> SubscriptionCardSize.COMPACT
    2 -> SubscriptionCardSize.COMFORTABLE
    else -> SubscriptionCardSize.EXPANDED
}

private fun boardCardActionInset(columnsCount: Int): Dp = when (columnsCount.coerceIn(1, 3)) {
    1 -> 32.dp
    else -> 0.dp
}

private fun boardCardPinnedInset(columnsCount: Int): Dp = when (columnsCount.coerceIn(1, 3)) {
    2 -> 34.dp
    else -> 0.dp
}

private data class BoardPreviewPlacement(
    val movingIds: List<UUID>,
    val insertionIndex: Int,
    val previewItems: List<DisplayedSubscription>,
)

private data class BoardGridEntry(
    val key: String,
    val item: DisplayedSubscription? = null,
    val previewItem: DisplayedSubscription? = null,
)

private enum class BillingUrgency {
    WARNING,
    CRITICAL,
}
