//
//  DesignSystem.swift
//  QuickOpener
//
//  深色/亮色双主题视觉规范：色板按窗口 appearance 自动解析，
//  数值来自设计稿（QuickOpener-UI-Concept），改动时请同步两者。
//

import SwiftUI

/// 全局视觉 token。颜色全部是「亮/暗双值」，随窗口外观自动切换。
enum DS {
    // 圆角
    static let radius: CGFloat = 12        // 窗口
    static let rowRadius: CGFloat = 7      // 列表行
    static let cardRadius: CGFloat = 9     // 设置卡片
    static let iconRadius: CGFloat = 6.5   // 应用图标

    // 文字层级
    static let text  = dynamic(hex(0x1A1D24), hex(0xE9EDF4))
    static let text2 = dynamic(hex(0x5A6272), hex(0x9AA3B4))
    static let text3 = dynamic(hex(0x8A93A3), hex(0x626B7C))

    // 线条与表面
    static let line     = dynamic(hex(0x000000, 0.09), hex(0xFFFFFF, 0.075))
    static let line2    = dynamic(hex(0x000000, 0.15), hex(0xFFFFFF, 0.135))
    static let surface  = dynamic(hex(0x000000, 0.032), hex(0xFFFFFF, 0.028))
    static let surface2 = dynamic(hex(0x000000, 0.050), hex(0xFFFFFF, 0.045))

    // 语义色（警示不跟主题色走）
    static let warn = dynamic(hex(0xC4701A), hex(0xFFB86B))

    /// 最强对比文字：选中行用（亮色下是纯黑，暗色下是纯白）
    static let textStrong = dynamic(hex(0x000000), hex(0xFFFFFF))

    /// 窗口高光边：亮色底上白色边看不见，改用淡黑
    static let hairline = dynamic(hex(0x000000, 0.10), hex(0xFFFFFF, 0.26))
    static let hairlineSoft = dynamic(hex(0x000000, 0.02), hex(0xFFFFFF, 0.03))

    /// 窗口底板渐变
    static var windowGradient: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(hex(0xFFFFFF), hex(0x1A1F2A)),
                dynamic(hex(0xF4F6FA), hex(0x0B0D14)),
                dynamic(hex(0xEAEDF3), hex(0x080A0F)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 「关于」卡片里的应用图标底
    static var iconPlate: LinearGradient {
        LinearGradient(
            colors: [
                dynamic(hex(0xE8EDF6), hex(0x20263A)),
                dynamic(hex(0xDCE3EE), hex(0x0E1119)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 等宽字体：快捷键、路径、数字统一用它获得「仪器感」。
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }

    // MARK: - 颜色构造

    private static func hex(_ value: UInt32, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// 亮/暗双值颜色：由 NSColor 动态解析，窗口换外观时自动跟着变。
    private static func dynamic(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}

/// 窗口材质：背后模糊（亮暗自适应，所以用 popover 而不是 hudWindow）。
///
/// 使用时窗口需要 `isOpaque = false` + `backgroundColor = .clear`，
/// 否则毛玻璃拿不到桌面内容，只会显示成一块纯色。
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

/// 1px 高光描边（顶部亮、底部暗）：用光线分层替代多层阴影。
struct GlassBorder: View {
    var cornerRadius: CGFloat = DS.radius

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [DS.hairline, DS.hairlineSoft],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

/// 标题栏拖动区。
///
/// `isMovableByWindowBackground` 只对未被内容消费的背景生效，
/// 窗口铺满 SwiftUI 视图后拖动会失效，因此用 AppKit 视图显式接管。
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }

        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

/// 键帽：统一快捷键徽标的字形、圆角与描边。
struct KeyCap: View {
    let text: String
    var tint: Color?
    var fontSize: CGFloat = 10

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .medium, design: .monospaced))
            .foregroundStyle(tint ?? DS.text)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 20)
            .background(tint.map { $0.opacity(0.08) } ?? DS.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(tint.map { $0.opacity(0.28) } ?? DS.line2, lineWidth: 1)
            )
    }
}
