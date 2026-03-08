package kr.co.cdd.payboard.core.designsystem.component

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import kr.co.cdd.payboard.core.designsystem.icon.PresetIconCatalog
import kr.co.cdd.payboard.core.designsystem.i18n.LocalPayBoardStrings
import kr.co.cdd.payboard.core.designsystem.theme.ColorTokens
import kr.co.cdd.payboard.core.designsystem.theme.PayBoardShapes
import kr.co.cdd.payboard.core.designsystem.theme.payIconColor
import kr.co.cdd.payboard.core.domain.model.Subscription
import java.time.Instant
import java.time.ZoneId

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SubscriptionCardView(
    subscription: Subscription,
    modifier: Modifier = Modifier,
    showIcon: Boolean = true,
    showDateBelowLabel: Boolean = false,
    referenceMonth: Instant = Instant.now(),
    billingDateOverride: Instant? = null,
    onTapIcon: (() -> Unit)? = null,
    onClick: (() -> Unit)? = null,
    onLongClick: (() -> Unit)? = null,
    trailingContent: @Composable (() -> Unit)? = null,
) {
    val strings = LocalPayBoardStrings.current
    val effectiveBillingDate = billingDateOverride ?: subscription.nextBillingDate
    val isPaidForReferenceMonth = subscription.lastPaymentDate?.isSameMonth(referenceMonth) == true
    val dueInDays = effectiveBillingDate.daysUntil()
    val cardBackground = when {
        isPaidForReferenceMonth -> Color.Green.copy(alpha = 0.18f)
        dueInDays <= 1 -> Color.Red.copy(alpha = 0.12f)
        dueInDays <= 3 -> Color.Yellow.copy(alpha = 0.18f)
        else -> MaterialTheme.colorScheme.surface
    }
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(PayBoardShapes.Card)
            .background(cardBackground, PayBoardShapes.Card)
            .then(
                if (onClick != null || onLongClick != null) {
                    Modifier.combinedClickable(
                        onClick = onClick ?: {},
                        onLongClick = onLongClick,
                    )
                } else {
                    Modifier
                }
            ),
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(verticalAlignment = Alignment.Top, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                if (showIcon) {
                    PayBoardIconBadge(
                        iconKey = subscription.iconKey,
                        iconColorKey = subscription.iconColorKey,
                        modifier = Modifier.size(36.dp),
                        onClick = onTapIcon,
                    )
                }

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = subscription.name,
                        style = MaterialTheme.typography.titleMedium,
                        maxLines = 1,
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = subscription.customCategoryName?.takeIf { subscription.category.name == "OTHER" }
                                ?: strings.categoryLabel(subscription.category),
                            style = MaterialTheme.typography.bodySmall,
                            color = payMuted(),
                            maxLines = 1,
                        )
                        if (subscription.isAutoPayEnabled) {
                            Text(text = "·", color = payMuted())
                            Text(
                                text = strings.autoPay,
                                style = MaterialTheme.typography.bodySmall,
                                color = ColorTokens.Success,
                                fontWeight = FontWeight.SemiBold,
                            )
                        }
                    }
                }

                if (trailingContent != null) {
                    trailingContent()
                }
            }

            Text(
                text = strings.formatCurrency(
                    amount = subscription.amount,
                    currencyCode = subscription.currencyCode,
                    isAmountUndecided = subscription.isAmountUndecided,
                ),
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.SemiBold,
            )

            if (showDateBelowLabel) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = if (isPaidForReferenceMonth) strings.paymentStatus else strings.nextBilling,
                        style = MaterialTheme.typography.bodySmall,
                        color = payMuted(),
                    )
                    Text(
                        text = if (isPaidForReferenceMonth) strings.paymentDone else strings.formatShortDate(effectiveBillingDate),
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                    )
                }
            } else {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = if (isPaidForReferenceMonth) strings.paymentStatus else strings.nextBilling,
                        style = MaterialTheme.typography.bodySmall,
                        color = payMuted(),
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        text = if (isPaidForReferenceMonth) strings.paymentDone else strings.formatShortDate(effectiveBillingDate),
                        style = MaterialTheme.typography.bodySmall,
                        fontWeight = FontWeight.Medium,
                    )
                }
            }
        }

        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(top = 12.dp, end = 12.dp)
        ) {
            if (subscription.isPinned) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(ColorTokens.Accent),
                )
            }
        }
    }
}

@Composable
fun PayBoardIconBadge(
    iconKey: String,
    iconColorKey: String,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
) {
    val presetIcon = remember(iconKey) { PresetIconCatalog.iconFor(iconKey) }
    val iconTint = payIconColor(iconColorKey)
    val backgroundColor = if (presetIcon != null) {
        Color.Black.copy(alpha = 0.05f)
    } else {
        iconTint.copy(alpha = 0.14f)
    }

    Box(
        modifier = modifier
            .clip(PayBoardShapes.Control)
            .background(backgroundColor)
            .then(
                if (onClick != null) {
                    Modifier.clickable(onClick = onClick)
                } else {
                    Modifier
                }
            ),
        contentAlignment = Alignment.Center,
    ) {
        if (presetIcon != null) {
            androidx.compose.foundation.Image(
                painter = painterResource(presetIcon.drawableResId),
                contentDescription = presetIcon.displayName,
                modifier = Modifier
                    .size(20.dp)
                    .padding(1.dp),
                contentScale = ContentScale.Fit,
            )
        } else {
            Text(
                text = iconKey.take(2).ifBlank { "?" },
                style = MaterialTheme.typography.labelLarge,
                color = iconTint,
            )
        }
    }
}

@Composable
private fun payMuted(): Color = if (MaterialTheme.colorScheme.background.luminance() > 0.5f) {
    ColorTokens.MutedLight
} else {
    ColorTokens.MutedDark
}

private fun Instant.daysUntil(reference: Instant = Instant.now()): Int =
    ((epochSecond - reference.epochSecond) / 86_400L).toInt()

private fun Instant.isSameMonth(reference: Instant): Boolean {
    val zone = ZoneId.systemDefault()
    val lhs = atZone(zone)
    val rhs = reference.atZone(zone)
    return lhs.year == rhs.year && lhs.monthValue == rhs.monthValue
}
