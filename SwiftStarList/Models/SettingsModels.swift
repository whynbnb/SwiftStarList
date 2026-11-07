import AppKit
import SwiftUI

enum AppLanguage: String, CaseIterable, Codable {
    case system = "system"
    case zh = "zh"
    case en = "en"

    var displayName: String {
        switch self {
        case .system: return L.s.systemLanguage
        case .zh: return "中文"
        case .en: return "English"
        }
    }

    /// 实际生效的语言：显式选择优先，`.system` 时跟随系统首选语言。
    static var resolved: AppLanguage {
        resolve(SettingsManager.shared.settings.language)
    }

    static func resolve(_ selected: AppLanguage) -> AppLanguage {
        selected == .system ? systemLanguage : selected
    }

    /// 系统首选语言（尊重 macOS 的「按 App 设置语言」）。
    static var systemLanguage: AppLanguage {
        // 不要用 Locale.current：它跟随的是区域格式（如 en_US），而非系统语言。
        let identifier = Locale.preferredLanguages.first
            ?? Locale.current.language.languageCode?.identifier
            ?? "en"
        return isChineseIdentifier(identifier) ? .zh : .en
    }

    /// 识别 zh、zh-Hans、zh-Hant、zh-CN 等所有中文标识。
    static func isChineseIdentifier(_ identifier: String) -> Bool {
        identifier.lowercased().hasPrefix("zh")
    }
}

enum AppTheme: String, CaseIterable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var displayName: String {
        switch self {
        case .system: return L.s.systemTheme
        case .light: return L.s.lightTheme
        case .dark: return L.s.darkTheme
        }
    }

    var appearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    var resolvedAppearance: NSAppearance {
        switch self {
        case .light: return NSAppearance(named: .aqua)!
        case .dark: return NSAppearance(named: .darkAqua)!
        case .system:
            let saved = NSApp.appearance
            NSApp.appearance = nil
            let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            NSApp.appearance = saved
            return isDark ? NSAppearance(named: .darkAqua)! : NSAppearance(named: .aqua)!
        }
    }

    var resolvedColorScheme: ColorScheme? {
        switch self {
        case .system:
            if SettingsManager.shared.isSettingsOpen {
                let saved = NSApp.appearance
                NSApp.appearance = nil
                let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                NSApp.appearance = saved
                return isDark ? .dark : .light
            } else {
                return nil
            }
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum ProxyMode: String, CaseIterable, Codable {
    case none = "none"
    case system = "system"
    case http = "http"
    case socks = "socks5"

    var displayName: String {
        switch self {
        case .none: return L.s.proxyNone
        case .system: return L.s.proxySystem
        case .http: return "HTTP"
        case .socks: return "SOCKS5"
        }
    }
}

struct ProxyConfig: Codable {
    var mode: ProxyMode
    var host: String
    var port: Int

    static let `default` = ProxyConfig(mode: .none, host: "127.0.0.1", port: 7890)
}

struct LLMConfig: Codable {
    var baseURL: String
    var apiKey: String
    var model: String
    var proxyConfig: ProxyConfig

    static let `default` = LLMConfig(baseURL: "https://api.openai.com", apiKey: "", model: "gpt-4o-mini", proxyConfig: .default)
}

struct AppSettings: Codable {
    var githubToken: String
    var githubProxyConfig: ProxyConfig
    var llmConfig: LLMConfig
    var autoAnalyze: Bool
    var language: AppLanguage
    var theme: AppTheme

    static let `default` = AppSettings(
        githubToken: "",
        githubProxyConfig: .default,
        llmConfig: .default,
        autoAnalyze: false,
        language: .system,
        theme: .system
    )
}
