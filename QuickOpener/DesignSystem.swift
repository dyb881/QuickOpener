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
    /// 毛玻璃自身的不透明度（0...1）。
    ///
    /// 只调上层遮挡是不够的：`NSVisualEffectView` 的材质本身是实心的，
    /// 遮挡层变淡后透出的是这层材质而不是桌面，看起来就像"透明度没反应"。
    var intensity: Double = 1.0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = false
        view.alphaValue = intensity
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.alphaValue = intensity
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

/// 异步字段占位条：数值算好之前先占住宽度，避免布局跳动。
struct SkeletonBar: View {
    var width: CGFloat = 28
    @State private var dim = false

    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(DS.surface2)
            .frame(width: width, height: 7)
            .opacity(dim ? 0.4 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    dim = true
                }
            }
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

        /// 只在自身 bounds 内响应。
        ///
        /// NSViewRepresentable 的 NSView 会先于同层 SwiftUI 控件拿到 AppKit 事件，
        /// 一旦它的 bounds 算得比预期大，就会把旁边按钮的点击吞掉（按下变成拖窗口）。
        /// 这里显式收敛命中范围，保证按钮区域不被覆盖。
        override func hitTest(_ point: NSPoint) -> NSView? {
            guard !isHidden, alphaValue > 0 else { return nil }
            return bounds.contains(convert(point, from: superview)) ? self : nil
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

/// 窗口背景：按用户选择的材质铺底。
///
/// 两个窗口（主窗口 / 偏好设置）共用，保证切换材质后观感一致。
struct WindowBackdropView: View {
    let backdrop: WindowBackdrop
    var opacity: Double = 1.0

    var body: some View {
        ZStack {
            if let material = backdrop.material {
                // 传 intensity：透明度直接削弱毛玻璃本身，才能真的透出桌面
                VisualEffectBackground(material: material, intensity: opacity)
            }

            DS.windowGradient.opacity(backdrop.overlay(userOpacity: opacity))

            if backdrop == .glass {
                // 玻璃模式加一层左上角高光，拉开与磨砂的观感差异
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .center
                )
                .allowsHitTesting(false)
            }
        }
    }
}


// MARK: - 细身滚动条

/// 滚动位置度量。
private struct SlimScrollMetrics: Equatable {
    var contentHeight: CGFloat = 0
    var offsetY: CGFloat = 0
}

private struct SlimScrollMetricsKey: PreferenceKey {
    static var defaultValue = SlimScrollMetrics()
    static func reduce(value: inout SlimScrollMetrics, nextValue: () -> SlimScrollMetrics) {
        value = nextValue()
    }
}

/// 隐藏系统滚动条，用主题色画一条 3.5pt 胶囊。
///
/// 系统滚动条（overlay 样式）是浅灰轨道，铺在深色玻璃背景上会突兀，
/// 而且在 `scrollIndicators(.automatic)` 下只随滚动短暂出现，位置感很弱。
struct SlimScrollView<Content: View>: View {
    var accent: Color
    @ViewBuilder var content: Content

    @State private var contentHeight: CGFloat = 1
    @State private var visibleHeight: CGFloat = 1
    @State private var offsetY: CGFloat = 0
    @State private var isHovering = false

    private static var space: String { "slimScrollSpace" }

    /// 滑块高度、可移动距离、当前进度；内容未超出时返回 nil（不画）。
    private var thumb: (height: CGFloat, travel: CGFloat, progress: CGFloat)? {
        guard contentHeight > visibleHeight + 0.5 else { return nil }
        let visibleRatio = visibleHeight / contentHeight
        let height = max(28, visibleHeight * visibleRatio)
        let travel = max(visibleHeight - height, 0)
        let maxScroll = max(contentHeight - visibleHeight, 1)
        let progress = min(max(offsetY / maxScroll, 0), 1)
        return (height, travel, progress)
    }

    var body: some View {
        GeometryReader { outer in
            ScrollView(.vertical, showsIndicators: false) {
                content
                    .background(
                        GeometryReader { inner in
                            Color.clear.preference(
                                key: SlimScrollMetricsKey.self,
                                value: SlimScrollMetrics(
                                    contentHeight: inner.size.height,
                                    offsetY: -inner.frame(in: .named(Self.space)).minY
                                )
                            )
                        }
                    )
            }
            .coordinateSpace(name: Self.space)
            .onPreferenceChange(SlimScrollMetricsKey.self) { metrics in
                contentHeight = max(metrics.contentHeight, 1)
                offsetY = metrics.offsetY
                visibleHeight = max(outer.size.height, 1)
            }
            .overlay(alignment: .trailing) {
                if let thumb {
                    Capsule()
                        .fill(accent.opacity(isHovering ? 0.7 : 0.34))
                        .frame(width: 3.5, height: thumb.height)
                        .offset(y: thumb.progress * thumb.travel)
                        .padding(.trailing, 3)
                        .allowsHitTesting(false)
                        .animation(.easeOut(duration: 0.15), value: isHovering)
                }
            }
            .onHover { isHovering = $0 }
        }
    }
}

