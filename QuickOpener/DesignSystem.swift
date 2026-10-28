//
//  DesignSystem.swift
//  QuickOpener
//
//  深色玻璃视觉规范：色板、圆角、材质背景与通用小组件。
//  数值来自设计稿（QuickOpener-UI-Concept），改动时请同步两者。
//

import SwiftUI

/// 全局视觉 token。
enum DS {
    // 圆角
    static let radius: CGFloat = 12        // 窗口
    static let rowRadius: CGFloat = 7      // 列表行
    static let cardRadius: CGFloat = 9     // 设置卡片
    static let iconRadius: CGFloat = 6.5   // 应用图标

    // 文字层级
    static let text = Color(red: 0.914, green: 0.929, blue: 0.957)   // #E9EDF4
    static let text2 = Color(red: 0.604, green: 0.639, blue: 0.706)  // #9AA3B4
    static let text3 = Color(red: 0.384, green: 0.420, blue: 0.486)  // #626B7C

    // 线条与表面
    static let line = Color.white.opacity(0.075)
    static let line2 = Color.white.opacity(0.135)
    static let surface = Color.white.opacity(0.028)
    static let surface2 = Color.white.opacity(0.045)

    // 语义色（警示不跟主题色走）
    static let warn = Color(red: 1.0, green: 0.722, blue: 0.420)     // #FFB86B

    /// 等宽字体：快捷键、路径、数字统一用它获得「仪器感」。
    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, design: .monospaced)
    }
}

/// 窗口材质：背后模糊的暗色玻璃（对应设计稿的 backdrop-filter）。
///
/// 使用时窗口需要 `isOpaque = false` + `backgroundColor = .clear`，
/// 否则毛玻璃拿不到桌面内容，只会显示成一块纯色。
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
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
    var topOpacity: Double = 0.26

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(topOpacity), .white.opacity(0.03)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .allowsHitTesting(false)
    }
}

/// 窗口底板：玻璃 + 深色渐变 + 圆角与高光边。
struct GlassPanel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                ZStack {
                    VisualEffectBackground(material: .hudWindow)
                    LinearGradient(
                        colors: [
                            Color(red: 0.102, green: 0.122, blue: 0.165).opacity(0.93),
                            Color(red: 0.043, green: 0.051, blue: 0.078).opacity(0.96),
                            Color(red: 0.031, green: 0.039, blue: 0.059).opacity(0.98),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
            .overlay(GlassBorder())
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
