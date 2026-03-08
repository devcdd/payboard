package kr.co.cdd.payboard.core.designsystem.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable

private val LightColors = lightColorScheme(
    primary = PayAccent,
    secondary = IconMint,
    error = PayDanger,
    background = PayBackgroundLight,
    surface = PaySurfaceLight,
    outline = PayOutlineLight,
)

private val DarkColors = darkColorScheme(
    primary = ColorTokens.Accent,
    secondary = IconMint,
    error = PayDanger,
    background = PayBackgroundDark,
    surface = PaySurfaceDark,
    outline = PayOutlineDark,
)

object ColorTokens {
    val Accent = PayAccent
    val Success = PaySuccess
    val Danger = PayDanger
    val MutedLight = PayTextMutedLight
    val MutedDark = PayTextMutedDark
}

object PayBoardSpacing {
    const val Xs = 4
    const val Sm = 8
    const val Md = 12
    const val Lg = 16
    const val Xl = 24
    const val Xxl = 32
}

object PayBoardRadius {
    const val Card = 16
    const val Control = 10
}

@Immutable
object PayBoardShapes {
    val Card = RoundedCornerShape(PayBoardRadius.Card)
    val Control = RoundedCornerShape(PayBoardRadius.Control)
}

@Composable
fun PayBoardTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        shapes = androidx.compose.material3.Shapes(
            small = PayBoardShapes.Control,
            medium = PayBoardShapes.Control,
            large = PayBoardShapes.Card,
        ),
        typography = PayBoardTypography,
        content = content,
    )
}
