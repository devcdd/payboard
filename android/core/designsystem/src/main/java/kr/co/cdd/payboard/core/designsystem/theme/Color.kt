package kr.co.cdd.payboard.core.designsystem.theme

import androidx.compose.ui.graphics.Color

internal val PayBackgroundLight = Color(0xFFF3F6FB)
internal val PayBackgroundDark = Color(0xFF0B1118)
internal val PaySurfaceLight = Color(0xFFFFFFFF)
internal val PaySurfaceDark = Color(0xFF121B24)
internal val PayOutlineLight = Color(0xFFD7E0EA)
internal val PayOutlineDark = Color(0xFF243342)
internal val PayAccent = Color(0xFF1172CC)
internal val PaySuccess = Color(0xFF118A57)
internal val PayDanger = Color(0xFFC74646)
internal val PayTextMutedLight = Color(0xFF5F6B78)
internal val PayTextMutedDark = Color(0xFF9AA8B6)

val IconBlue = Color(0xFF1172CC)
val IconGreen = Color(0xFF1F9D63)
val IconRed = Color(0xFFD14E4E)
val IconOrange = Color(0xFFE5921B)
val IconPurple = Color(0xFF7A63D2)
val IconMint = Color(0xFF2AA7A1)

fun payIconColor(key: String): Color = when (key.lowercase()) {
    "green" -> IconGreen
    "red" -> IconRed
    "orange" -> IconOrange
    "purple" -> IconPurple
    "mint" -> IconMint
    else -> IconBlue
}
