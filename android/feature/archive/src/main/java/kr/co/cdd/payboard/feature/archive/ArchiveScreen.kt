package kr.co.cdd.payboard.feature.archive

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kr.co.cdd.payboard.core.designsystem.component.PayBoardPanel
import kr.co.cdd.payboard.core.domain.model.Subscription
import java.time.ZoneId
import java.time.format.DateTimeFormatter

@Composable
fun ArchiveRoute(viewModel: ArchiveViewModel) {
    val archived by viewModel.archivedSubscriptions.collectAsStateWithLifecycle()
    ArchiveScreen(
        subscriptions = archived,
        onRestore = viewModel::restore,
        onDelete = viewModel::delete,
    )
}

@Composable
fun ArchiveScreen(
    subscriptions: List<Subscription>,
    onRestore: (Subscription) -> Unit,
    onDelete: (Subscription) -> Unit,
) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Archive", style = MaterialTheme.typography.headlineMedium)
                Text(
                    "Archived subscriptions stay recoverable while Android catches up with iOS behavior.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        if (subscriptions.isEmpty()) {
            item {
                PayBoardPanel {
                    Text("No archived subscriptions.")
                }
            }
        } else {
            items(subscriptions, key = { it.id }) { subscription ->
                PayBoardPanel {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Text(subscription.name, style = MaterialTheme.typography.titleMedium)
                        Text(
                            "Archived ${subscription.updatedAt.formatDate()}",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                        ) {
                            Button(onClick = { onRestore(subscription) }, modifier = Modifier.weight(1f)) {
                                Text("Restore")
                            }
                            Button(onClick = { onDelete(subscription) }, modifier = Modifier.weight(1f)) {
                                Text("Delete")
                            }
                        }
                    }
                }
            }
        }
    }
}

private fun java.time.Instant.formatDate(): String = DateTimeFormatter.ofPattern("yyyy.MM.dd")
    .withZone(ZoneId.systemDefault())
    .format(this)
