package kr.co.cdd.payboard.core.designsystem.icon

import androidx.annotation.DrawableRes
import androidx.compose.runtime.Immutable
import java.util.Locale
import kr.co.cdd.payboard.core.designsystem.R

@Immutable
data class PresetIcon(
    val key: String,
    val displayName: String,
    @DrawableRes val drawableResId: Int,
    val colorKey: String,
    val aliases: List<String> = emptyList(),
    val legacyKeys: List<String> = emptyList(),
)

object PresetIconCatalog {
    val all: List<PresetIcon> = listOf(
        PresetIcon("icon_alami", "Alami", R.drawable.icon_alami, "orange", listOf("알라미", "식비"), legacyKeys = listOf("alami")),
        PresetIcon("icon_adobe", "Adobe", R.drawable.icon_adobe, "red", listOf("어도비", "크리에이티브"), legacyKeys = listOf("adobe")),
        PresetIcon("icon_apple_music", "Apple Music", R.drawable.icon_apple_music, "red", listOf("애플", "애플뮤직", "음악"), legacyKeys = listOf("apple_music", "AM")),
        PresetIcon("icon_spotify", "Spotify", R.drawable.icon_spotify, "green", listOf("스포티파이", "음악"), legacyKeys = listOf("spotify", "SP", "S")),
        PresetIcon("icon_netflix", "Netflix", R.drawable.icon_netflix, "red", listOf("넷플릭스", "영상"), legacyKeys = listOf("netflix", "N")),
        PresetIcon("icon_doeat", "Doeat", R.drawable.icon_doeat, "orange", listOf("두잇", "식비"), legacyKeys = listOf("doeat")),
        PresetIcon("icon_youtube", "YouTube", R.drawable.icon_youtube, "red", listOf("유튜브", "영상"), legacyKeys = listOf("youtube", "YT")),
        PresetIcon("icon_disney", "Disney+", R.drawable.icon_disney, "blue", listOf("디즈니", "영상"), legacyKeys = listOf("disney_plus", "D+")),
        PresetIcon("icon_duolingo", "Duolingo", R.drawable.icon_duolingo, "green", listOf("듀오링고", "교육", "학습"), legacyKeys = listOf("duolingo", "DL")),
        PresetIcon("icon_naver_plus", "Naver Plus", R.drawable.icon_naver_plus, "green", listOf("네이버플러스", "멤버십"), legacyKeys = listOf("naver_plus", "NB")),
        PresetIcon("icon_milli", "Millie", R.drawable.icon_milli, "blue", listOf("밀리", "독서", "도서"), legacyKeys = listOf("milli", "ML")),
        PresetIcon("icon_electric", "Electricity", R.drawable.icon_electric, "orange", listOf("전기", "전기세", "한전"), legacyKeys = listOf("electric")),
        PresetIcon("icon_gas_app", "Gas App", R.drawable.icon_gas_app, "orange", listOf("가스앱", "도시가스", "난방"), legacyKeys = listOf("gas_app")),
        PresetIcon("icon_icloud", "iCloud+", R.drawable.icon_icloud, "blue", listOf("아이클라우드", "클라우드"), legacyKeys = listOf("icloud", "IC", "i")),
        PresetIcon("icon_watcha", "Watcha", R.drawable.icon_watcha, "purple", listOf("왓챠", "영상"), legacyKeys = listOf("watcha", "W")),
        PresetIcon("icon_laftel", "Laftel", R.drawable.icon_laftel, "purple", listOf("라프텔", "애니"), legacyKeys = listOf("laftel")),
        PresetIcon("icon_kakao", "Kakao", R.drawable.icon_kakao, "orange", listOf("카카오", "메신저"), legacyKeys = listOf("kakao")),
        PresetIcon("icon_github", "GitHub", R.drawable.icon_github, "blue", listOf("깃허브", "개발", "코드"), legacyKeys = listOf("github", "GH")),
        PresetIcon("icon_notion", "Notion", R.drawable.icon_notion, "blue", listOf("노션", "메모", "문서"), legacyKeys = listOf("notion", "NT")),
        PresetIcon("icon_photoshop", "Photoshop", R.drawable.icon_photoshop, "blue", listOf("포토샵", "디자인"), legacyKeys = listOf("photoshop")),
        PresetIcon("icon_slack", "Slack", R.drawable.icon_slack, "purple", listOf("슬랙", "협업", "업무"), legacyKeys = listOf("slack")),
        PresetIcon("icon_apple_tv", "Apple TV+", R.drawable.icon_apple_tv, "blue", listOf("애플티비", "영상"), legacyKeys = listOf("apple_tv")),
        PresetIcon("icon_aws", "AWS", R.drawable.icon_aws, "orange", listOf("아마존웹서비스", "cloud", "서버"), legacyKeys = listOf("aws", "AWS")),
        PresetIcon("icon_gemini", "Gemini", R.drawable.icon_gemini, "blue", listOf("제미니", "ai"), legacyKeys = listOf("gemini")),
        PresetIcon("icon_google_cloud", "Google Cloud", R.drawable.icon_google_cloud, "blue", listOf("구글클라우드", "gcp", "클라우드"), legacyKeys = listOf("google_cloud")),
        PresetIcon("icon_google_playpass", "Google Play Pass", R.drawable.icon_google_playpass, "green", listOf("플레이패스", "구글플레이", "게임"), legacyKeys = listOf("google_playpass")),
        PresetIcon("icon_naver_cloud_platform", "Naver Cloud Platform", R.drawable.icon_naver_cloud_platform, "green", listOf("ncp", "네이버클라우드", "클라우드"), legacyKeys = listOf("naver_cloud_platform")),
        PresetIcon("icon_tving", "TVING", R.drawable.icon_tving, "red", listOf("티빙", "영상"), legacyKeys = listOf("tving", "TV")),
        PresetIcon("icon_gpt", "GPT", R.drawable.icon_gpt, "green", listOf("gpt", "챗지피티", "ai"), legacyKeys = listOf("chatgpt", "GPT")),
        PresetIcon("icon_claude", "Claude", R.drawable.icon_claude, "orange", listOf("클로드", "ai"), legacyKeys = listOf("claude", "CL")),
        PresetIcon("icon_perplexity", "Perplexity", R.drawable.icon_perplexity, "purple", listOf("퍼플렉시티", "ai"), legacyKeys = listOf("perplexity", "PX")),
        PresetIcon("logo_coupang", "Coupang", R.drawable.logo_coupang, "orange", listOf("쿠팡", "쇼핑"), legacyKeys = listOf("coupang", "CP")),
    )

    private val iconByKey: Map<String, PresetIcon> = buildMap {
        all.forEach { icon ->
            put(icon.key, icon)
            icon.legacyKeys.forEach { legacyKey -> put(legacyKey, icon) }
        }
    }

    fun iconFor(key: String): PresetIcon? = iconByKey[key]

    fun search(query: String): List<PresetIcon> {
        val normalizedQuery = normalize(query)
        if (normalizedQuery.isBlank()) {
            return all
        }
        return all.filter { icon ->
            normalize(icon.displayName).contains(normalizedQuery) ||
                normalize(icon.key).contains(normalizedQuery) ||
                icon.aliases.any { normalize(it).contains(normalizedQuery) } ||
                icon.legacyKeys.any { normalize(it).contains(normalizedQuery) }
        }
    }

    private fun normalize(text: String): String = text
        .lowercase(Locale.ROOT)
        .replace(" ", "")
        .replace("_", "")
        .replace("-", "")
}
