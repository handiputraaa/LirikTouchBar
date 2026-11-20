import Foundation

private enum SettingsKey {
    static let refreshInterval = "refreshInterval"
    static let fontSize = "fontSize"
    static let lineCount = "lineCount"
    static let showMenuBar = "showMenuBar"
    static let fallbackText = "fallbackText"
}

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private init() {}

    @Published var refreshInterval: Double =
        UserDefaults.standard.object(forKey: SettingsKey.refreshInterval) as? Double ?? 0.5 {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: SettingsKey.refreshInterval) }
    }

    @Published var fontSize: Double =
        UserDefaults.standard.object(forKey: SettingsKey.fontSize) as? Double ?? 15 {
        didSet { UserDefaults.standard.set(fontSize, forKey: SettingsKey.fontSize) }
    }

    @Published var lineCount: Int =
        UserDefaults.standard.object(forKey: SettingsKey.lineCount) as? Int ?? 2 {
        didSet { UserDefaults.standard.set(lineCount, forKey: SettingsKey.lineCount) }
    }

    @Published var showMenuBar: Bool =
        UserDefaults.standard.object(forKey: SettingsKey.showMenuBar) as? Bool ?? true {
        didSet { UserDefaults.standard.set(showMenuBar, forKey: SettingsKey.showMenuBar) }
    }

    @Published var fallbackText: String =
        UserDefaults.standard.string(forKey: SettingsKey.fallbackText) ?? "♪ No lyrics for this track" {
        didSet { UserDefaults.standard.set(fallbackText, forKey: SettingsKey.fallbackText) }
    }
}
