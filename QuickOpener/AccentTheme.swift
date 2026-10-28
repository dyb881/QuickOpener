//
//  AccentTheme.swift
//  QuickOpener
//
//  主题强调色：在设置界面选择，持久化到 UserDefaults，全局即时生效。
//

import Combine
import SwiftUI

/// 可选的主题强调色。`system` 表示跟随 macOS 系统强调色设置。
enum AccentTheme: String, CaseIterable, Identifiable {
    case system
    case mint
    case blue
    case purple
    case orange
    case pink

    var id: String { rawValue }

    /// 设置界面展示用的本地化 key。
    var localizedKey: String { "theme_\(rawValue)" }

    /// 预设颜色；`system` 返回 nil，调用方回退到系统强调色。
    var presetColor: Color? {
        switch self {
        case .system: return nil
        case .mint:   return Color(red: 0.431, green: 0.906, blue: 0.816)
        case .blue:   return Color(red: 0.302, green: 0.639, blue: 1.000)
        case .purple: return Color(red: 0.690, green: 0.486, blue: 1.000)
        case .orange: return Color(red: 1.000, green: 0.722, blue: 0.420)
        case .pink:   return Color(red: 1.000, green: 0.494, blue: 0.659)
        }
    }
}

/// 主题管理：读写主题色，变化时通过 `@Published` 驱动所有观察者重绘。
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let storageKey = "accentTheme"

    @Published var theme: AccentTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.storageKey) }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: Self.storageKey)
        theme = saved.flatMap(AccentTheme.init(rawValue:)) ?? .system
    }

    /// 当前生效的强调色（`system` 时回退到系统强调色）。
    var accent: Color { theme.presetColor ?? .accentColor }
}
