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

extension Color {
    /// 从 "RRGGBB" / "#RRGGBB" 还原颜色，用于自定义强调色的持久化。
    init?(hexString: String) {
        var text = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(
            red:   Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue:  Double(value & 0xFF) / 255
        )
    }
}

/// 可选的主题强调色。`system` 表示跟随 macOS 系统强调色设置。
enum AccentTheme: String, CaseIterable, Identifiable {
    case system
    case mint
    case blue
    case purple
    case orange
    case pink
    /// 用户自定义色，取 `ThemeManager.customAccent`。
    case custom

    var id: String { rawValue }

    /// 设置界面展示用的本地化 key。
    var localizedKey: String { "theme_\(rawValue)" }

    /// 预设颜色；`system` 与 `custom` 返回 nil，由 ThemeManager 决定实际颜色。
    var presetColor: Color? {
        switch self {
        case .system: return nil
        case .custom: return nil
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
    private static let customAccentKey = "customAccentHex"

    @Published var theme: AccentTheme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: Self.accentKey) }
    }

    /// 自定义强调色。改动即存 hex，并自动把主题切到 `.custom`，
    /// 这样在取色器里选完颜色就立刻生效，不需要再点一次色块。
    @Published var customAccent: Color {
        didSet {
            Self.saveCustomAccent(customAccent)
            if theme != .custom { theme = .custom }
        }
    }

    /// 未设置过自定义色时的默认值（中性灰蓝，不抢眼）。
    static let defaultCustomAccent = Color(red: 0.541, green: 0.576, blue: 0.651)

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
        didSet {
            UserDefaults.standard.set(windowOpacity, forKey: Self.opacityKey)
        }
    }

    init() {
        // customAccent 必须先于 theme 赋值：它的 didSet 会读 theme
        customAccent = Self.loadCustomAccent()
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
    // MARK: - 自定义色持久化

    static func loadCustomAccent() -> Color {
        guard let hex = UserDefaults.standard.string(forKey: customAccentKey),
              let color = Color(hexString: hex) else {
            return defaultCustomAccent
        }
        return color
    }

    static func saveCustomAccent(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .systemGray
        let hex = String(
            format: "%02X%02X%02X",
            Int((ns.redComponent * 255).rounded()),
            Int((ns.greenComponent * 255).rounded()),
            Int((ns.blueComponent * 255).rounded())
        )
        UserDefaults.standard.set(hex, forKey: customAccentKey)
    }

    var accent: Color {
        switch theme {
        case .custom: return customAccent
        case .system: return .accentColor
        default:      return theme.presetColor ?? .accentColor
        }
    }

    /// 材质切换后同步所有窗口的透明设置。
    ///
    /// 三种材质都保持窗口透明：背景一律由 SwiftUI 的 `WindowBackdropView` 铺，
    /// `solid` 用不透明渐变填满即可。若让窗口 `isOpaque = true`，
    /// `clipShape` 圆角之外会露出窗口底色，角落变成方块。
    /// 只有主窗口是透明的（材质需要），设置窗口保持不透明，
    /// 否则它的系统标题栏会变成透视、和内容区割裂。
    func applyBackdrop() {
        for window in NSApp.windows
        where window.identifier?.rawValue == "mainWindow" {
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
    ///
    /// 不直接用 `baseOverlay * userOpacity`：那样拉到 35% 时遮挡只剩 0.19 以下，
    /// 文字会直接糊在壁纸上。这里保留 30% 的保底遮挡，让变化明显但还能读。
    func overlay(userOpacity: Double) -> Double {
        let floor = baseOverlay * 0.3
        return floor + (baseOverlay - floor) * userOpacity
    }
}
