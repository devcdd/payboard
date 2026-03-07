import Foundation
import Domain

public enum PresetIconCatalog {
    private static let appLanguageDefaultsKey = "settings.appLanguage"
    private static let supportedLanguageCodes = ["ko", "en"]

    public static func all() -> [PresetIcon] {
        let assetBased: [PresetIcon] = [
            PresetIcon(key: "icon_alami", displayName: "Alami", displayNameKey: "icon.name.alami", systemSymbol: "fork.knife", assetName: "icon_alami", aliases: ["알라미", "alami", "식비"]),
            PresetIcon(key: "icon_adobe", displayName: "Adobe", displayNameKey: "icon.name.adobe", systemSymbol: "scribble.variable", assetName: "icon_adobe", aliases: ["어도비", "adobe", "크리에이티브"]),
            PresetIcon(key: "icon_apple_music", displayName: "Apple", displayNameKey: "icon.name.apple", systemSymbol: "music.note", assetName: "icon_apple_music", aliases: ["애플", "애플뮤직", "apple", "apple music", "음악"]),
            PresetIcon(key: "icon_spotify", displayName: "Spotify", displayNameKey: "icon.name.spotify", systemSymbol: "music.note.list", assetName: "icon_spotify", aliases: ["스포티파이", "spotify", "음악"]),
            PresetIcon(key: "icon_netflix", displayName: "Netflix", displayNameKey: "icon.name.netflix", systemSymbol: "play.tv", assetName: "icon_netflix", aliases: ["넷플릭스", "netflix", "영상"]),
            PresetIcon(key: "icon_doeat", displayName: "Doeat", displayNameKey: "icon.name.doeat", systemSymbol: "fork.knife.circle", assetName: "icon_doeat", aliases: ["두잇", "doeat", "식비"]),
            PresetIcon(key: "icon_youtube", displayName: "YouTube", displayNameKey: "icon.name.youtube", systemSymbol: "play.rectangle", assetName: "icon_youtube", aliases: ["유튜브", "youtube", "영상"]),
            PresetIcon(key: "icon_disney", displayName: "Disney+", displayNameKey: "icon.name.disney_plus", systemSymbol: "sparkles.tv", assetName: "icon_disney", aliases: ["디즈니", "disney", "영상"]),
            PresetIcon(key: "icon_duolingo", displayName: "Duolingo", displayNameKey: "icon.name.duolingo", systemSymbol: "character.book.closed", assetName: "icon_duolingo", aliases: ["듀오링고", "duolingo", "교육", "학습"]),
            PresetIcon(key: "icon_naver_plus", displayName: "Naver Plus", displayNameKey: "icon.name.naver_plus", systemSymbol: "plus.circle", assetName: "icon_naver_plus", aliases: ["네이버플러스", "naver plus", "naver", "멤버십"]),
            PresetIcon(key: "icon_milli", displayName: "Millie", displayNameKey: "icon.name.millie", systemSymbol: "book", assetName: "icon_milli", aliases: ["밀리", "milli", "독서", "도서"]),
            PresetIcon(key: "icon_electric", displayName: "Electricity", displayNameKey: "icon.name.electricity", systemSymbol: "bolt", assetName: "icon_electric", aliases: ["전기", "전기세", "electric", "utility", "한전"]),
            PresetIcon(key: "icon_gas_app", displayName: "Gas App", displayNameKey: "icon.name.gas_app", systemSymbol: "flame", assetName: "icon_gas_app", aliases: ["가스앱", "도시가스", "난방"]),
            PresetIcon(key: "icon_icloud", displayName: "iCloud+", displayNameKey: "icon.name.icloud_plus", systemSymbol: "icloud", assetName: "icon_icloud", aliases: ["아이클라우드", "icloud", "클라우드"]),
            PresetIcon(key: "icon_watcha", displayName: "Watcha", displayNameKey: "icon.name.watcha", systemSymbol: "tv", assetName: "icon_watcha", aliases: ["왓챠", "watcha", "영상"]),
            PresetIcon(key: "icon_laftel", displayName: "Laftel", displayNameKey: "icon.name.laftel", systemSymbol: "film", assetName: "icon_laftel", aliases: ["라프텔", "laftel", "애니"]),
            PresetIcon(key: "icon_kakao", displayName: "Kakao", displayNameKey: "icon.name.kakao", systemSymbol: "message", assetName: "icon_kakao", aliases: ["카카오", "kakao", "메신저"]),
            PresetIcon(key: "icon_github", displayName: "GitHub", displayNameKey: "icon.name.github", systemSymbol: "chevron.left.forwardslash.chevron.right", assetName: "icon_github", aliases: ["깃허브", "github", "개발", "코드"]),
            PresetIcon(key: "icon_notion", displayName: "Notion", displayNameKey: "icon.name.notion", systemSymbol: "doc.text", assetName: "icon_notion", aliases: ["노션", "notion", "메모", "문서"]),
            PresetIcon(key: "icon_photoshop", displayName: "Photoshop", displayNameKey: "icon.name.photoshop", systemSymbol: "photo.artframe", assetName: "icon_photoshop", aliases: ["포토샵", "photoshop", "디자인", "어도비"]),
            PresetIcon(key: "icon_slack", displayName: "Slack", displayNameKey: "icon.name.slack", systemSymbol: "message.badge", assetName: "icon_slack", aliases: ["슬랙", "slack", "협업", "업무"]),
            PresetIcon(key: "icon_apple_tv", displayName: "Apple TV+", displayNameKey: "icon.name.apple_tv", systemSymbol: "tv", assetName: "icon_apple_tv", aliases: ["애플티비", "apple tv", "영상"]),
            PresetIcon(key: "icon_aws", displayName: "AWS", displayNameKey: "icon.name.aws", systemSymbol: "server.rack", assetName: "icon_aws", aliases: ["aws", "아마존웹서비스", "cloud", "서버"]),
            PresetIcon(key: "icon_gemini", displayName: "Gemini", displayNameKey: "icon.name.gemini", systemSymbol: "sparkles", assetName: "icon_gemini", aliases: ["제미니", "gemini", "ai"]),
            PresetIcon(key: "icon_google_cloud", displayName: "Google Cloud", displayNameKey: "icon.name.google_cloud", systemSymbol: "cloud", assetName: "icon_google_cloud", aliases: ["구글클라우드", "gcp", "google cloud"]),
            PresetIcon(key: "icon_google_playpass", displayName: "Google Play Pass", displayNameKey: "icon.name.google_playpass", systemSymbol: "gamecontroller", assetName: "icon_google_playpass", aliases: ["플레이패스", "play pass", "구글플레이"]),
            PresetIcon(key: "icon_naver_cloud_platform", displayName: "Naver Cloud Platform", displayNameKey: "icon.name.naver_cloud_platform", systemSymbol: "cloud.fill", assetName: "icon_naver_cloud_platform", aliases: ["ncp", "네이버클라우드", "naver cloud", "클라우드"]),
            PresetIcon(key: "icon_tving", displayName: "TVING", displayNameKey: "icon.name.tving", systemSymbol: "play.tv", assetName: "icon_tving", aliases: ["티빙", "tving", "영상"]),
            PresetIcon(key: "icon_gpt", displayName: "GPT", displayNameKey: "icon.name.gpt", systemSymbol: "brain", assetName: "icon_gpt", aliases: ["gpt", "챗지피티", "ai"]),
            PresetIcon(key: "icon_claude", displayName: "Claude", displayNameKey: "icon.name.claude", systemSymbol: "brain.head.profile", assetName: "icon_claude", aliases: ["클로드", "claude", "ai"]),
            PresetIcon(key: "icon_perplexity", displayName: "Perplexity", displayNameKey: "icon.name.perplexity", systemSymbol: "magnifyingglass", assetName: "icon_perplexity", aliases: ["퍼플렉시티", "perplexity", "ai"]),
            PresetIcon(key: "logo_coupang", displayName: "Coupang", displayNameKey: "icon.name.coupang", systemSymbol: "cart", assetName: "logo_coupang", aliases: ["쿠팡", "coupang", "쇼핑"])
        ]
        let base: [PresetIcon] = [
            PresetIcon(key: "netflix", displayName: "Netflix", displayNameKey: "icon.name.netflix", systemSymbol: "play.tv", assetName: "icon_netflix", aliases: ["넷플릭스", "net", "movie", "video"]),
            PresetIcon(key: "youtube", displayName: "YouTube Premium", displayNameKey: "icon.name.youtube_premium", systemSymbol: "play.rectangle", assetName: "icon_youtube", aliases: ["유튜브", "youtube", "yt", "video"]),
            PresetIcon(key: "spotify", displayName: "Spotify", displayNameKey: "icon.name.spotify", systemSymbol: "music.note.list", aliases: ["스포티파이", "music", "음악"]),
            PresetIcon(key: "apple_music", displayName: "Apple", displayNameKey: "icon.name.apple", systemSymbol: "music.note", assetName: "icon_apple_music", aliases: ["애플", "애플뮤직", "apple", "music", "음악"]),
            PresetIcon(key: "disney_plus", displayName: "Disney+", displayNameKey: "icon.name.disney_plus", systemSymbol: "sparkles.tv", assetName: "icon_disney", aliases: ["디즈니", "디즈니플러스", "movie", "video"]),
            PresetIcon(key: "notion", displayName: "Notion", displayNameKey: "icon.name.notion", systemSymbol: "doc.text", aliases: ["노션", "메모", "문서", "productivity"]),
            PresetIcon(key: "icloud", displayName: "iCloud+", displayNameKey: "icon.name.icloud_plus", systemSymbol: "icloud", assetName: "icon_icloud", aliases: ["아이클라우드", "클라우드", "저장공간"]),
            PresetIcon(key: "chatgpt", displayName: "ChatGPT Plus", displayNameKey: "icon.name.chatgpt_plus", systemSymbol: "brain", assetName: "icon_gpt", aliases: ["챗지피티", "ai", "gpt"]),
            PresetIcon(key: "github", displayName: "GitHub", displayNameKey: "icon.name.github", systemSymbol: "chevron.left.forwardslash.chevron.right", aliases: ["깃허브", "개발", "코드", "git"]),
            PresetIcon(key: "dropbox", displayName: "Dropbox", displayNameKey: "icon.name.dropbox", systemSymbol: "shippingbox", aliases: ["드롭박스", "클라우드", "저장공간"])
        ]

        var extended = assetBased + base
        let symbols = [
            "app.badge", "bag", "cart", "film", "gamecontroller", "book", "graduationcap", "heart.text.square",
            "newspaper", "figure.run", "dollarsign.circle", "creditcard", "fork.knife", "tv", "display", "headphones",
            "cloud", "shield", "clock", "calendar", "camera", "phone", "message", "map", "car", "tram", "house",
            "wifi", "antenna.radiowaves.left.and.right", "star", "wand.and.stars", "bolt", "leaf", "flame", "pawprint"
        ]

        for index in 1...210 {
            let key = "preset_\(index)"
            let display = "Apple Icon \(String(format: "%03d", index))"
            let symbol = symbols[index % symbols.count]
            extended.append(PresetIcon(key: key, displayName: display, systemSymbol: symbol))
        }

        return extended
    }

    public static func icon(for key: String) -> PresetIcon? {
        all().first(where: { $0.key == key })
    }

    public static func localizedDisplayName(for icon: PresetIcon) -> String {
        let languageCode = UserDefaults.standard.string(forKey: appLanguageDefaultsKey) ?? "ko"
        return localizedDisplayName(for: icon, languageCode: languageCode)
    }

    public static func search(_ query: String) -> [PresetIcon] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return all()
        }
        let normalizedQuery = normalized(trimmedQuery)
        return all().filter { icon in
            let localizedNames = localizedDisplayNames(for: icon)
            return localizedNames.contains(where: { normalized($0).contains(normalizedQuery) })
            || normalized(icon.displayName).contains(normalizedQuery)
            || normalized(icon.key).contains(normalizedQuery)
            || normalized(icon.systemSymbol).contains(normalizedQuery)
            || icon.aliases.contains(where: { normalized($0).contains(normalizedQuery) })
        }
    }

    private static func localizedDisplayName(for icon: PresetIcon, languageCode: String) -> String {
        guard let key = icon.displayNameKey else { return icon.displayName }
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return icon.displayName
        }
        return bundle.localizedString(forKey: key, value: icon.displayName, table: nil)
    }

    private static func localizedDisplayNames(for icon: PresetIcon) -> [String] {
        var results = [icon.displayName]
        for languageCode in supportedLanguageCodes {
            let name = localizedDisplayName(for: icon, languageCode: languageCode)
            if !results.contains(name) {
                results.append(name)
            }
        }
        return results
    }

    private static func normalized(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }
}
