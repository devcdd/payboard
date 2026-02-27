import Foundation
import Domain

public enum PresetIconCatalog {
    public static func all() -> [PresetIcon] {
        let base: [PresetIcon] = [
            PresetIcon(key: "netflix", displayName: "Netflix", systemSymbol: "play.tv"),
            PresetIcon(key: "youtube", displayName: "YouTube Premium", systemSymbol: "play.rectangle"),
            PresetIcon(key: "spotify", displayName: "Spotify", systemSymbol: "music.note.list"),
            PresetIcon(key: "apple_music", displayName: "Apple Music", systemSymbol: "music.note"),
            PresetIcon(key: "disney_plus", displayName: "Disney+", systemSymbol: "sparkles.tv"),
            PresetIcon(key: "notion", displayName: "Notion", systemSymbol: "doc.text"),
            PresetIcon(key: "icloud", displayName: "iCloud+", systemSymbol: "icloud"),
            PresetIcon(key: "chatgpt", displayName: "ChatGPT Plus", systemSymbol: "brain"),
            PresetIcon(key: "github", displayName: "GitHub", systemSymbol: "chevron.left.forwardslash.chevron.right"),
            PresetIcon(key: "dropbox", displayName: "Dropbox", systemSymbol: "shippingbox")
        ]

        var extended = base
        let symbols = [
            "app.badge", "bag", "cart", "film", "gamecontroller", "book", "graduationcap", "heart.text.square",
            "newspaper", "figure.run", "dollarsign.circle", "creditcard", "fork.knife", "tv", "display", "headphones",
            "cloud", "shield", "clock", "calendar", "camera", "phone", "message", "map", "car", "tram", "house",
            "wifi", "antenna.radiowaves.left.and.right", "star", "wand.and.stars", "bolt", "leaf", "flame", "pawprint"
        ]

        for index in 1...210 {
            let key = "preset_\(index)"
            let display = "Preset Service \(String(format: "%03d", index))"
            let symbol = symbols[index % symbols.count]
            extended.append(PresetIcon(key: key, displayName: display, systemSymbol: symbol))
        }

        return extended
    }

    public static func search(_ query: String) -> [PresetIcon] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return all()
        }
        return all().filter { icon in
            icon.displayName.localizedCaseInsensitiveContains(query) || icon.key.localizedCaseInsensitiveContains(query)
        }
    }
}
