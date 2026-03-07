package kr.co.cdd.payboard.feature.board

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kr.co.cdd.payboard.core.designsystem.component.PayBoardPanel
import kr.co.cdd.payboard.core.designsystem.theme.ColorTokens
import kr.co.cdd.payboard.core.designsystem.theme.payIconColor
import kr.co.cdd.payboard.core.domain.model.BillingCycle
import kr.co.cdd.payboard.core.domain.model.Subscription
import java.math.BigDecimal
import java.math.RoundingMode
import java.text.NumberFormat
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalLayoutApi::class)
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
    )
}

@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
fun BoardScreen(
    state: BoardUiState,
    displayMode: BoardDisplayMode,
    isSearchVisible: Boolean,
    onSearchQueryChange: (String) -> Unit,
    onFilterSelected: (BoardFilter) -> Unit,
    onMarkPaymentComplete: (Subscription) -> Unit,
    onArchive: (Subscription) -> Unit,
) {
    val totalMonthly = state.subscriptions.fold(BigDecimal.ZERO) { acc, subscription ->
        val normalizedAmount = when (subscription.billingCycle) {
            BillingCycle.Monthly -> subscription.amount
            BillingCycle.Yearly -> subscription.amount.divide(BigDecimal("12"), 0, RoundingMode.HALF_UP)
            is BillingCycle.CustomDays -> subscription.amount
        }
        acc.add(normalizedAmount)
    }
    val nextDue = state.subscriptions.minByOrNull(Subscription::nextBillingDate)

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(MaterialTheme.colorScheme.background),
        contentPadding = PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = if (displayMode == BoardDisplayMode.BOARD) "Subscription Board" else "Billing Calendar",
                    style = MaterialTheme.typography.headlineMedium,
                )
                Text(
                    text = "Mirror the iOS information architecture first, then expand feature depth on Android.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = mutedColor(),
                )
            }
        }

        item {
            PayBoardPanel {
                Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    Text("Overview", style = MaterialTheme.typography.titleMedium)
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                    ) {
                        SummaryMetric("Active", state.subscriptions.size.toString(), Modifier.weight(1f))
                        SummaryMetric("Monthly", formatCurrency(totalMonthly), Modifier.weight(1f))
                    }
                    SummaryMetric(
                        "Next due",
                        nextDue?.let { "${it.name} · ${it.nextBillingDate.asDisplayDate()}" } ?: "No active subscriptions",
                    )
                }
            }
        }

        item {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                if (isSearchVisible) {
                    OutlinedTextField(
                        value = state.searchQuery,
                        onValueChange = onSearchQueryChange,
                        modifier = Modifier.fillMaxWidth(),
                        label = { Text("Search subscriptions") },
                        singleLine = true,
                    )
                }
                FlowRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    BoardFilter.entries.forEach { filter ->
                        FilterChip(
                            onClick = { onFilterSelected(filter) },
                            selected = state.selectedFilter == filter,
                            label = { Text(filter.label) },
                        )
                    }
                }
            }
        }

        if (state.subscriptions.isEmpty()) {
            item {
                PayBoardPanel {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("No subscriptions yet", style = MaterialTheme.typography.titleMedium)
                        Text(
                            "The Android shell is wired. Next step is the editor flow and backup integration.",
                            style = MaterialTheme.typography.bodyMedium,
                            color = mutedColor(),
                        )
                    }
                }
            }
        } else if (displayMode == BoardDisplayMode.BOARD) {
            item {
                LazyVerticalGrid(
                    columns = GridCells.Adaptive(minSize = 180.dp),
                    modifier = Modifier.height((state.subscriptions.size.coerceAtLeast(1) * 172).dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    userScrollEnabled = false,
                ) {
                    items(state.subscriptions, key = { it.id }) { subscription ->
                        SubscriptionCard(
                            subscription = subscription,
                            onMarkPaymentComplete = { onMarkPaymentComplete(subscription) },
                            onArchive = { onArchive(subscription) },
                        )
                    }
                }
            }
        } else {
            state.subscriptions
                .groupBy { it.nextBillingDate.asDisplayDate() }
                .forEach { (date, subscriptions) ->
                    stickyHeader {
                        Surface(
                            modifier = Modifier.fillMaxWidth(),
                            color = MaterialTheme.colorScheme.background,
                        ) {
                            Text(
                                text = date,
                                modifier = Modifier.padding(vertical = 8.dp),
                                style = MaterialTheme.typography.titleMedium,
                            )
                        }
                    }
                    items(subscriptions.size) { index ->
                        SubscriptionCard(
                            subscription = subscriptions[index],
                            onMarkPaymentComplete = { onMarkPaymentComplete(subscriptions[index]) },
                            onArchive = { onArchive(subscriptions[index]) },
                        )
                        Spacer(modifier = Modifier.height(12.dp))
                    }
                }
        }
    }
}

@Composable
private fun SummaryMetric(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier) {
        Text(label, style = MaterialTheme.typography.labelLarge, color = mutedColor())
        Spacer(modifier = Modifier.height(4.dp))
        Text(value, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
    }
}

@Composable
private fun SubscriptionCard(
    subscription: Subscription,
    onMarkPaymentComplete: () -> Unit,
    onArchive: () -> Unit,
) {
    PayBoardPanel {
        Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Box(
                    modifier = Modifier
                        .background(
                            color = payIconColor(subscription.iconColorKey).copy(alpha = 0.15f),
                            shape = MaterialTheme.shapes.medium,
                        )
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                ) {
                    Text(
                        text = subscription.iconKey.take(2),
                        style = MaterialTheme.typography.titleMedium,
                        color = payIconColor(subscription.iconColorKey),
                    )
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(subscription.name, style = MaterialTheme.typography.titleMedium)
                    Text(subscription.category.label, style = MaterialTheme.typography.bodyMedium, color = mutedColor())
                }
            }
            Text(formatCurrency(subscription.amount), style = MaterialTheme.typography.headlineMedium)
            Text(
                "Next billing ${subscription.nextBillingDate.asDisplayDate()}",
                style = MaterialTheme.typography.bodyMedium,
                color = mutedColor(),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = onMarkPaymentComplete, modifier = Modifier.weight(1f)) {
                    Text("Paid")
                }
                Button(onClick = onArchive, modifier = Modifier.weight(1f)) {
                    Text("Archive")
                }
            }
        }
    }
}

@Composable
private fun mutedColor() = if (MaterialTheme.colorScheme.isLight()) {
    ColorTokens.MutedLight
} else {
    ColorTokens.MutedDark
}

private fun androidx.compose.material3.ColorScheme.isLight(): Boolean = background.luminance() > 0.5f

private fun formatCurrency(amount: java.math.BigDecimal): String {
    val formatter = NumberFormat.getCurrencyInstance(java.util.Locale.KOREA)
    return formatter.format(amount.toLong())
}

private fun java.time.Instant.asDisplayDate(): String = DateTimeFormatter.ofPattern("MMM d")
    .withZone(ZoneId.systemDefault())
    .format(this)
