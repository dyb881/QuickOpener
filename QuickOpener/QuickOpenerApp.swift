//
//  QuickOpenerApp.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import KeyboardShortcuts
import SwiftData
import SwiftUI

/// 定义全局快捷键名称，用于切换项目窗口的显示/隐藏。
extension KeyboardShortcuts.Name {
    /// 切换项目窗口的快捷键，默认为 Option + Z。
    static let toggleProjectOpener = Self("toggleProjectOpener", default: .init(.z, modifiers: .option))
}

/// 主应用程序入口，配置无默认窗口，使用菜单栏图标和全局快捷键。
@main
struct QuickOpenerApp: App {
    /// 应用程序代理，管理菜单栏图标和窗口行为。
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    /// 共享的 SwiftData 模型容器，存储 `ApplicationModel` 和 `ProjectModel` 数据。
    static let sharedModelContainer: ModelContainer = {
        let schema = Schema([ApplicationModel.self, ProjectModel.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// 数据管理器实例，使用共享模型容器的主上下文。
    static let dataManager = DataManager(modelContext: sharedModelContainer.mainContext)

    /// 定义应用程序的场景，包含设置视图。
    var body: some Scene {
        Settings {
            SettingsView()
                .modelContainer(QuickOpenerApp.sharedModelContainer)
                .environmentObject(QuickOpenerApp.dataManager)
                .environmentObject(ThemeManager.shared)
        }
    }
}

/// 应用程序代理，管理菜单栏图标、全局快捷键和窗口的生命周期。
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// 项目窗口的内容尺寸（与 ContentView 的固定 frame 保持一致）。
    private static let contentSize = NSSize(width: 780, height: 514)

    /// 主窗口引用，存储当前打开的窗口。
    var window: NSWindow?

    /// 设置窗口引用
    var settingsWindow: NSWindow?

    /// 菜单栏状态栏项，用于显示应用程序图标和菜单。
    var statusItem: NSStatusItem?

    /// 窗口内键盘事件监视器（ESC / ↑↓ / 回车 / ⌘数字）
    var keyMonitor: Any?

    /// 标题栏快捷键提示标签（随快捷键设置更新）
    /// 快捷键提示已改由 SwiftUI 标题栏渲染，无需原生标签。

    /// 快捷键变化通知的观察者
    var shortcutObserver: NSObjectProtocol?

    /// 应用程序启动完成时调用，装配菜单栏、快捷键与首次启动行为。
    func applicationDidFinishLaunching(_: Notification) {
        ThemeManager.shared.applyAppearance() // 应用上次保存的外观模式（亮/暗/跟随系统）
        setupStatusItem() // 菜单栏图标与菜单（AppDelegate+StatusItem.swift）
        setupShortcutObserver() // 快捷键变化时刷新标题栏提示（AppDelegate+Keyboard.swift）

        // 注册全局快捷键
        KeyboardShortcuts.onKeyDown(for: .toggleProjectOpener) { [weak self] in
            self?.toggleWindow() // 触发显示/隐藏窗口
        }

        // 仅首次运行时自动显示窗口；之后静默启动，避免每次登录自启都弹窗
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: "hasLaunchedBefore") {
            defaults.set(true, forKey: "hasLaunchedBefore")
            showWindow()
        }
    }

    /// 退出应用程序。
    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    /// 显示窗口，若窗口不存在则创建新窗口。
    @objc func showWindow() {
        print("AppDelegate: showWindow")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 每次显示前刷新一次失效项目状态（窗口常驻后文件可能已被移走）
            QuickOpenerApp.dataManager.refreshMissingPaths()
            self.updateShortcutLabel()
            if let existingWindow = self.window {
                self.activateWindow(existingWindow)
                self.positionWindowAtCursor(existingWindow)
            } else {
                self.createNewWindow()
            }
        }
    }

    /// 显示/隐藏窗口（全局快捷键入口）。窗口已在前台时隐藏，否则显示。
    func toggleWindow() {
        print("AppDelegate: toggleWindow")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let window = self.window, window.isVisible, NSApp.isActive {
                self.hideWindow(window)
            } else {
                self.showWindow()
            }
        }
    }

    /// 隐藏窗口。窗口实例与视图状态保留，下次显示直接复用。
    func hideWindow(_ window: NSWindow) {
        print("AppDelegate: hideWindow")
        window.orderOut(nil)
    }

    /// 激活现有窗口并将其置于前台。
    /// - Parameter window: 要激活的窗口。
    func activateWindow(_ window: NSWindow) {
        print("AppDelegate: activateWindow")
        window.makeKeyAndOrderFront(nil) // 设置窗口为主窗口并显示
        NSApp.activate(ignoringOtherApps: true) // 激活应用程序，忽略其他应用
    }

    /// 创建并显示新窗口，定位于鼠标光标附近。
    private func createNewWindow() {
        print("AppDelegate: createNewWindow")
        let newWindow = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.contentSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        // 深色玻璃外观：透明窗口 + 隐藏标题栏，圆角与高光边由 SwiftUI 自绘
        newWindow.isOpaque = false
        newWindow.backgroundColor = .clear
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.styleMask.insert(.fullSizeContentView)
        newWindow.appearance = ThemeManager.shared.appearance.nsAppearance
        let hostingController = NSHostingController(rootView:
            ContentView()
                .modelContainer(QuickOpenerApp.sharedModelContainer)
                .environmentObject(QuickOpenerApp.dataManager)
                .environmentObject(ThemeManager.shared)
        )
        newWindow.contentViewController = hostingController
        newWindow.collectionBehavior = [.managed, .moveToActiveSpace]
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false // 窗口关闭时保留引用
        newWindow.isMovableByWindowBackground = true // 允许通过背景拖动窗口
        // 隐藏左上角红绿灯：纯菜单栏交互，关闭用 Esc，移动靠拖动背景
        newWindow.standardWindowButton(.closeButton)?.isHidden = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isHidden = true
        newWindow.standardWindowButton(.zoomButton)?.isHidden = true
        newWindow.isFloatingPanel = true // 设置面板为浮动层级
        newWindow.becomesKeyOnlyIfNeeded = true // 仅在需要时成为 key（如 Sheet 模态），兼容 beginSheetModal
        newWindow.title = "QuickOpener"

        // 将窗口引用传递给 DataManager，用于 NSOpenPanel 的 Sheet 模态
        QuickOpenerApp.dataManager.hostingWindow = newWindow

        // 先按鼠标位置定位，再激活显示，避免窗口先在屏幕角落闪一下
        newWindow.setFrameOrigin(targetOrigin(for: newWindow, mouse: NSEvent.mouseLocation))
        activateWindow(newWindow)
        window = newWindow

        // 注册键盘监听
        setupKeyMonitor()
    }

    /// 将窗口定位到鼠标光标附近。
    /// - Parameter window: 要定位的窗口。
    private func positionWindowAtCursor(_ window: NSWindow) {
        print("AppDelegate: positionWindowAtCursor")
        window.setFrameOrigin(targetOrigin(for: window, mouse: NSEvent.mouseLocation))
    }

    /// 计算窗口应放置的原点：顶边位于光标下方 8pt，并完整限制在光标所在屏幕的可见区域内。
    private func targetOrigin(for window: NSWindow, mouse: NSPoint) -> NSPoint {
        let size = window.frame.size
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 8

        var x = mouse.x - 390 // 窗口水平居中于光标（780 / 2）

        // 光标落在窗口顶部内侧 `cursorInset` 处（正好是输入行那一格）：
        // 窗口向上兜住鼠标、主要向下展开，比「顶边贴在光标下方」贴得近得多
        let cursorInset: CGFloat = 44
        var y = mouse.y + cursorInset - size.height

        // 钳制到可见区域内（多显示器 / 靠近屏幕边缘时不会跑出屏幕）
        if visible.width > size.width + margin * 2 {
            x = min(max(x, visible.minX + margin), visible.maxX - size.width - margin)
        } else {
            x = visible.minX + margin
        }
        if visible.height > size.height + margin * 2 {
            y = min(max(y, visible.minY + margin), visible.maxY - size.height - margin)
        } else {
            y = visible.minY + margin
        }
        return NSPoint(x: x, y: y)
    }

    /// 当窗口失去激活状态时隐藏窗口（保留实例，方便下次复用同一份视图状态）。
    func windowDidResignKey(_ notification: Notification) {
        // NSOpenPanel 等模态弹窗运行时，不隐藏窗口
        guard NSApp.modalWindow == nil else { return }
        print("AppDelegate: windowDidResignKey")
        guard let window = notification.object as? NSWindow, window == self.window else { return }
        guard window.isVisible else { return } // orderOut 期间可能再次收到通知，避免重入
        hideWindow(window)
    }

    /// 点击标题栏关闭按钮时只隐藏窗口，不销毁实例。
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard sender == window else { return true }
        hideWindow(sender)
        return false
    }

    /// 窗口关闭时清除窗口引用和 ESC 键监视器。
    func windowWillClose(_ notification: Notification) {
        print("AppDelegate: windowWillClose")
        if let closingWindow = notification.object as? NSWindow {
            if closingWindow == window {
                // 移除键盘监听
                removeKeyMonitor()
                window = nil
            } else if closingWindow == settingsWindow {
                settingsWindow = nil
            }
        }
    }
}
