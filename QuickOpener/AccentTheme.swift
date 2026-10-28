//
//  AccentTheme.swift
//  QuickOpener
//
//  外观设置：主题强调色 + 界面外观模式（跟随系统 / 亮色 / 暗色）。
//  两者都持久化到 UserDefaults，切换后立即生效。
//

import AppKit
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

/// 界面外观：跟随系统 / 强制亮色 / 强制暗色。
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizedKey: String { "appearance_\(rawValue)" }

    /// nil 表示跟随系统。
    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light:  return NSAppearance(named: .aqua)
        case .dark:   return NSAppearance(named: .darkAqua)
        }
    }
}

/// 主题管理：读写强调色与外观模式，变化时驱动所有观察者重绘。
@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private static let accentKey = "accentTheme"
    private static let appearanceKey = "appearanceMode"

    @Published var theme: AccentTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.accentKey) }
    }

    @Published var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
            applyAppearance()
        }
    }

    init() {
        let savedAccent = UserDefaults.standard.string(forKey: Self.accentKey)
        theme = savedAccent.flatMap(AccentTheme.init(rawValue:)) ?? .system
        let savedAppearance = UserDefaults.standard.string(forKey: Self.appearanceKey)
        appearance = savedAppearance.flatMap(AppearanceMode.init(rawValue:)) ?? .system
    }

    /// 当前生效的强调色（`system` 时回退到系统强调色）。
    var accent: Color { theme.presetColor ?? .accentColor }

    /// 把外观应用到整个 App 与所有已存在的窗口，切换后无需重启。
    func applyAppearance() {
        let nsAppearance = appearance.nsAppearance
        NSApp.appearance = nsAppearance
        for window in NSApp.windows {
            window.appearance = nsAppearance
        }
    }
}
