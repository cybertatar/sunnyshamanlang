import Foundation

/// Настройки в UserDefaults.
@MainActor
final class Settings {
    static let shared = Settings()

    /// Где колдуем по умолчанию: Telegram (обе версии) и популярные мессенджеры.
    static let defaultApps: [String] = [
        "ru.keepcoder.Telegram",        // Telegram для macOS
        "com.tdesktop.Telegram",        // Telegram Desktop
        "com.apple.MobileSMS",          // Сообщения
        "net.whatsapp.WhatsApp",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
    ]

    private let defaults = UserDefaults.standard

    /// Колдовать при отправке.
    var isEnabled: Bool {
        get { defaults.object(forKey: "enabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "enabled") }
    }

    /// Показывать шамана над строкой.
    var showsShaman: Bool {
        get { defaults.object(forKey: "showsShaman") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "showsShaman") }
    }

    /// Колдовать во всех приложениях, а не только в списке.
    var allApps: Bool {
        get { defaults.bool(forKey: "allApps") }
        set { defaults.set(newValue, forKey: "allApps") }
    }

    var apps: Set<String> {
        Set(defaults.stringArray(forKey: "apps") ?? Self.defaultApps)
    }

    func works(in bundleID: String?) -> Bool {
        guard let bundleID, bundleID != Bundle.main.bundleIdentifier else { return false }
        return allApps || apps.contains(bundleID)
    }
}
