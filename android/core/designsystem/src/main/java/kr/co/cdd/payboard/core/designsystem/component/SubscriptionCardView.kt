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
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
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
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kr.co.cdd.payboard.core.designsystem.icon.PresetIconCatalog
import kr.co.cdd.payboard.core.designsystem.i18n.LocalPayBoardStrings
import kr.co.cdd.payboard.core.designsystem.theme.ColorTokens
import kr.co.cdd.payboard.core.designsystem.theme.PayBoardShapes
import kr.co.cdd.payboard.core.designsystem.theme.payIconColor
import kr.co.cdd.payboard.core.domain.model.Subscription
import java.time.Instant
import java.time.ZoneId

enum class SubscriptionCardSize {
    EXPANDED,
    COMFORTABLE,
    COMPACT,
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun SubscriptionCardView(
    subscription: Subscription,
    modifier: Modifier = Modifier,
    size: SubscriptionCardSize = SubscriptionCardSize.EXPANDED,
    contentEndInset: Dp = 0.dp,
    pinnedIndicatorEndInset: Dp = 0.dp,
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
    val layout = rememberSubscriptionCardLayout(size = size)
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
            .then(
                if (layout.fixedHeight != null) {
                    Modifier.height(layout.fixedHeight)
                } else {
                    Modifier.heightIn(min = layout.minHeight)
                }
            )
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
                .padding(
                    start = layout.contentPadding,
                    top = layout.contentPadding,
                    end = layout.contentPadding + contentEndInset,
                    bottom = layout.contentPadding,
                ),
            verticalArrangement = Arrangement.spacedBy(layout.verticalSpacing),
        ) {
            Row(
                verticalAlignment = Alignment.Top,
                horizontalArrangement = Arrangement.spacedBy(layout.topRowSpacing),
            ) {
                if (showIcon) {
                    PayBoardIconBadge(
                        iconKey = subscription.iconKey,
                        iconColorKey = subscription.iconColorKey,
                        modifier = Modifier.size(layout.iconBadgeSize),
                        contentSize = layout.iconContentSize,
                        onClick = onTapIcon,
                    )
                }

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                ) {
                    Text(
                        text = subscription.name,
                        style = layout.titleStyle,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            text = subscription.customCategoryName?.takeIf { subscription.category.name == "OTHER" }
                                ?: strings.categoryLabel(subscription.category),
                            style = layout.metaStyle,
                            color = payMuted(),
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                        if (subscription.isAutoPayEnabled) {
                            Text(text = "·", color = payMuted())
                            Text(
                                text = strings.autoPay,
                                style = layout.metaStyle,
                                color = ColorTokens.Success,
                                fontWeight = FontWeight.SemiBold,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
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
                style = layout.amountStyle,
                fontWeight = FontWeight.SemiBold,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )

            if (showDateBelowLabel) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = if (isPaidForReferenceMonth) strings.paymentStatus else strings.nextBilling,
                        style = layout.metaStyle,
                        color = payMuted(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = if (isPaidForReferenceMonth) strings.paymentDone else strings.formatShortDate(effectiveBillingDate),
                        style = layout.metaStyle,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            } else {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = if (isPaidForReferenceMonth) strings.paymentStatus else strings.nextBilling,
                        style = layout.metaStyle,
                        color = payMuted(),
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        text = if (isPaidForReferenceMonth) strings.paymentDone else strings.formatShortDate(effectiveBillingDate),
                        style = layout.metaStyle,
                        fontWeight = FontWeight.Medium,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
            }
        }

        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .padding(
                    top = layout.contentPadding,
                    end = layout.contentPadding + pinnedIndicatorEndInset,
                )
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
    contentSize: Dp = 28.dp,
    onClick: (() -> Unit)? = null,
) {
    val presetIcon = remember(iconKey) { PresetIconCatalog.iconFor(iconKey) }
    val iconTint = payIconColor(iconColorKey)
    val backgroundColor = if (presetIcon != null) {
        Color.Transparent
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
                modifier = Modifier.size(contentSize),
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
private fun rememberSubscriptionCardLayout(size: SubscriptionCardSize): SubscriptionCardLayout {
    val typography = MaterialTheme.typography
    return remember(size, typography) {
        when (size) {
            SubscriptionCardSize.EXPANDED -> SubscriptionCardLayout(
                minHeight = 132.dp,
                contentPadding = 12.dp,
                verticalSpacing = 8.dp,
                topRowSpacing = 8.dp,
                iconBadgeSize = 36.dp,
                iconContentSize = 28.dp,
                titleStyle = typography.titleMedium,
                amountStyle = typography.titleLarge,
                metaStyle = typography.bodySmall,
            )
            SubscriptionCardSize.COMFORTABLE -> SubscriptionCardLayout(
                minHeight = 122.dp,
                contentPadding = 10.dp,
                verticalSpacing = 6.dp,
                topRowSpacing = 7.dp,
                iconBadgeSize = 34.dp,
                iconContentSize = 25.dp,
                titleStyle = typography.titleMedium.copy(
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                ),
                amountStyle = typography.titleLarge.copy(
                    fontSize = 18.sp,
                    lineHeight = 23.sp,
                ),
                metaStyle = typography.bodySmall.copy(
                    fontSize = 11.sp,
                    lineHeight = 14.sp,
                ),
            )
            SubscriptionCardSize.COMPACT -> SubscriptionCardLayout(
                minHeight = 112.dp,
                fixedHeight = 112.dp,
                contentPadding = 9.dp,
                verticalSpacing = 5.dp,
                topRowSpacing = 6.dp,
                iconBadgeSize = 30.dp,
                iconContentSize = 22.dp,
                titleStyle = typography.titleMedium.copy(
                    fontSize = 14.sp,
                    lineHeight = 18.sp,
                ),
                amountStyle = typography.titleLarge.copy(
                    fontSize = 16.sp,
                    lineHeight = 20.sp,
                ),
                metaStyle = typography.bodySmall.copy(
                    fontSize = 10.sp,
                    lineHeight = 13.sp,
                ),
            )
        }
    }
}

private data class SubscriptionCardLayout(
    val minHeight: Dp,
    val fixedHeight: Dp? = null,
    val contentPadding: Dp,
    val verticalSpacing: Dp,
    val topRowSpacing: Dp,
    val iconBadgeSize: Dp,
    val iconContentSize: Dp,
    val titleStyle: TextStyle,
    val amountStyle: TextStyle,
    val metaStyle: TextStyle,
)

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
