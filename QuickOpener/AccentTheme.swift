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
    private static let backdropKey = "windowBackdrop"
    private static let opacityKey = "windowOpacity"

    @Published var theme: AccentTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.accentKey) }
    }

    @Published var appearance: AppearanceMode {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
            applyAppearance()
        }
    }

    @Published var backdrop: WindowBackdrop {
        didSet {
            UserDefaults.standard.set(backdrop.rawValue, forKey: Self.backdropKey)
            applyBackdrop()
        }
    }

    /// 窗口背景不透明度（0.35 最透 ~ 1.0 最实）。
    /// 只影响背景层，文字与控件不受影响。
    @Published var windowOpacity: Double {
        didSet { UserDefaults.standard.set(windowOpacity, forKey: Self.opacityKey) }
    }

    init() {
        let savedAccent = UserDefaults.standard.string(forKey: Self.accentKey)
        theme = savedAccent.flatMap(AccentTheme.init(rawValue:)) ?? .system
        let savedAppearance = UserDefaults.standard.string(forKey: Self.appearanceKey)
        appearance = savedAppearance.flatMap(AppearanceMode.init(rawValue:)) ?? .system
        let savedBackdrop = UserDefaults.standard.string(forKey: Self.backdropKey)
        backdrop = savedBackdrop.flatMap(WindowBackdrop.init(rawValue:)) ?? .frosted
        let savedOpacity = UserDefaults.standard.object(forKey: Self.opacityKey) as? Double
        windowOpacity = savedOpacity ?? 1.0
    }

    /// 当前生效的强调色（`system` 时回退到系统强调色）。
    var accent: Color { theme.presetColor ?? .accentColor }

    /// 材质切换后同步所有窗口的透明设置。
    ///
    /// 三种材质都保持窗口透明：背景一律由 SwiftUI 的 `WindowBackdropView` 铺，
    /// `solid` 用不透明渐变填满即可。若让窗口 `isOpaque = true`，
    /// `clipShape` 圆角之外会露出窗口底色，角落变成方块。
    func applyBackdrop() {
        for window in NSApp.windows {
            window.isOpaque = false
            window.backgroundColor = .clear
        }
    }

    /// 把外观应用到整个 App 与所有已存在的窗口，切换后无需重启。
    func applyAppearance() {
        let nsAppearance = appearance.nsAppearance
        NSApp.appearance = nsAppearance
        for window in NSApp.windows {
            window.appearance = nsAppearance
        }
    }
}

/// 窗口背景材质。
///
/// - `solid`：不透明深色渐变，性能最好、文字对比最稳
/// - `frosted`：系统 `.underWindowBackground` 毛玻璃，模糊强、有降噪，传统 macOS 观感
/// - `glass`：`.fullScreenUI` 轻薄材质 + 低透明度叠加 + 左上高光，接近 Liquid Glass
enum WindowBackdrop: String, CaseIterable, Identifiable {
    case solid
    case frosted
    case glass

    var id: String { rawValue }
    var localizedKey: String { "backdrop_\(rawValue)" }

    /// `solid` 不铺毛玻璃，返回 nil。
    var material: NSVisualEffectView.Material? {
        switch self {
        case .solid:   return nil
        case .frosted: return .underWindowBackground
        case .glass:   return .fullScreenUI
        }
    }

    /// 盖在材质上的暗色渐变**基准**强度（还要再乘用户设定的窗口不透明度）。
    /// 玻璃要更透，磨砂要压住背景保证可读性。
    var baseOverlay: Double {
        switch self {
        case .solid:   return 1.0
        case .frosted: return 0.55
        case .glass:   return 0.30
        }
    }

    /// 叠上用户透明度后的最终遮挡强度。
    /// `solid` 也会跟着变透（成为半透明纯色），这样滑块在三种模式下都有意义。
    func overlay(userOpacity: Double) -> Double {
        baseOverlay * userOpacity
    }
}
