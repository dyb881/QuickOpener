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
        }
    }
}

/// 应用程序代理，管理菜单栏图标、全局快捷键和窗口的生命周期。
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    /// 项目窗口的内容尺寸（与 ContentView 的固定 frame 保持一致）。
    private static let contentSize = NSSize(width: 300, height: 500)

    /// 主窗口引用，存储当前打开的窗口。
    private var window: NSWindow?

    /// 设置窗口引用
    private var settingsWindow: NSWindow?

    /// 菜单栏状态栏项，用于显示应用程序图标和菜单。
    private var statusItem: NSStatusItem?

    /// ESC 键事件监视器
    private var escKeyMonitor: Any?

    /// 应用程序启动完成时调用，设置菜单栏图标、菜单和全局快捷键。
    func applicationDidFinishLaunching(_: Notification) {
        // 设置菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let image = NSImage(named: "MenuIcon")
            image?.size = NSSize(width: 18, height: 18) // 调整图标大小以适配菜单栏
            button.image = image
        }

        // 创建菜单栏菜单
        let menu = NSMenu()

        // 显示窗口
        let menuShowWindowItem = NSMenuItem(title: NSLocalizedString("menu_show_window", comment: "Show window in status menu"), action: #selector(showWindow), keyEquivalent: "z")
        menuShowWindowItem.keyEquivalentModifierMask = .option
        menu.addItem(menuShowWindowItem)

        menu.addItem(NSMenuItem.separator()) // 分割线

        // 显示设置
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_settings", comment: "Open settings in status menu"), action: #selector(showSetting), keyEquivalent: ""))

        // 重置缓存
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_reset_cache", comment: "Reset cache in status menu"), action: #selector(resetCache), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator()) // 分割线

        // 退出
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_quit", comment: "Quit in status menu"), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu

        // 注册全局快捷键
        KeyboardShortcuts.onKeyDown(for: .toggleProjectOpener) { [weak self] in
            self?.toggleWindow() // 触发显示/隐藏窗口
        }

        // 初次启动时显示窗口
        showWindow()
    }

    /// 重置数据管理器的缓存（先弹确认，避免误触清空数据）并重新显示窗口。
    @objc func resetCache() {
        print("AppDelegate: resetCache")
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("reset_cache_confirm_title", comment: "Reset cache confirmation title")
        alert.informativeText = NSLocalizedString("reset_cache_confirm_message", comment: "Reset cache confirmation message")
        alert.addButton(withTitle: NSLocalizedString("button_cancel", comment: "Cancel button"))
        alert.addButton(withTitle: NSLocalizedString("button_clear", comment: "Clear button"))
        // 让 statusItem 菜单先收起，避免在菜单事件中同步 runModal
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard alert.runModal() == .alertSecondButtonReturn else { return }
            QuickOpenerApp.dataManager.clearCache()
            self.showWindow()
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
    private func hideWindow(_ window: NSWindow) {
        print("AppDelegate: hideWindow")
        window.orderOut(nil)
    }

    /// 激活现有窗口并将其置于前台。
    /// - Parameter window: 要激活的窗口。
    private func activateWindow(_ window: NSWindow) {
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
        let hostingController = NSHostingController(rootView:
            ContentView()
                .modelContainer(QuickOpenerApp.sharedModelContainer)
                .environmentObject(QuickOpenerApp.dataManager)
        )
        newWindow.contentViewController = hostingController
        newWindow.collectionBehavior = [.managed, .moveToActiveSpace]
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false // 窗口关闭时保留引用
        newWindow.isMovableByWindowBackground = true // 允许通过背景拖动窗口
        newWindow.standardWindowButton(.miniaturizeButton)?.isEnabled = false // 禁用最小化按钮
        newWindow.standardWindowButton(.zoomButton)?.isEnabled = false // 禁用缩放按钮
        newWindow.isFloatingPanel = true // 设置面板为浮动层级
        newWindow.becomesKeyOnlyIfNeeded = true // 仅在需要时成为 key（如 Sheet 模态），兼容 beginSheetModal
        newWindow.title = "QuickOpener"

        // 将窗口引用传递给 DataManager，用于 NSOpenPanel 的 Sheet 模态
        QuickOpenerApp.dataManager.hostingWindow = newWindow

        let controller = NSTitlebarAccessoryViewController()
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 60, height: 24)) // 调整容器大小
        let textField = NSTextField(labelWithString: "⌥ + Z")
        textField.alignment = .center // 文本居中
        textField.frame = containerView.bounds // 使用 containerView 的边界
        containerView.addSubview(textField)
        controller.view = containerView
        controller.layoutAttribute = .trailing
        newWindow.addTitlebarAccessoryViewController(controller)

        // 先按鼠标位置定位，再激活显示，避免窗口先在屏幕角落闪一下
        newWindow.setFrameOrigin(targetOrigin(for: newWindow, mouse: NSEvent.mouseLocation))
        activateWindow(newWindow)
        window = newWindow

        // 注册 ESC 键监听
        setupEscKeyMonitor()
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
        let gap: CGFloat = 8

        var x = mouse.x - 60
        var y = mouse.y - size.height - gap

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

    /// 设置 ESC 键事件监视器
    private func setupEscKeyMonitor() {
        // 先移除现有的监视器
        removeEscKeyMonitor()

        // 添加新的本地事件监视器
        escKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, event.keyCode == 53 else { return event } // 53 是 ESC 键的 keyCode
            // 有模态面板（NSOpenPanel / NSAlert）时，把 ESC 交还给面板自己处理
            guard NSApp.modalWindow == nil else { return event }
            // 只有项目窗口持有键盘焦点时才响应，避免误关其它窗口的输入
            guard let window = self.window, window.isKeyWindow else { return event }
            self.hideWindow(window)
            return nil // 阻止事件继续传递
        }
    }

    /// 移除 ESC 键事件监视器
    private func removeEscKeyMonitor() {
        if let monitor = escKeyMonitor {
            NSEvent.removeMonitor(monitor)
            escKeyMonitor = nil
        }
    }

    /// 打开设置窗口
    @objc func showSetting() {
        print("AppDelegate: showSetting")
        if let existingWindow = settingsWindow, !existingWindow.isReleasedWhenClosed {
            activateWindow(existingWindow)
        } else {
            let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
            let windowRect = NSRect(
                x: screenFrame.midX - 250,
                y: screenFrame.midY - 400,
                width: 500,
                height: 300
            )
            let newWindow = NSWindow(
                contentRect: windowRect,
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            let hostingController = NSHostingController(rootView:
                SettingsView()
                    .modelContainer(QuickOpenerApp.sharedModelContainer)
                    .environmentObject(QuickOpenerApp.dataManager)
                    .frame(width: 500, height: 300)
            )
            newWindow.contentViewController = hostingController
            newWindow.delegate = self
            newWindow.isReleasedWhenClosed = false
            newWindow.isMovableByWindowBackground = true // 允许通过背景拖动窗口
            newWindow.standardWindowButton(.miniaturizeButton)?.isEnabled = false // 禁用最小化按钮
            newWindow.standardWindowButton(.zoomButton)?.isEnabled = false // 禁用缩放按钮
            newWindow.title = NSLocalizedString("menu_settings", comment: "Settings window title")
            activateWindow(newWindow)
            settingsWindow = newWindow
        }
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
                // 移除 ESC 键监视器
                removeEscKeyMonitor()
                window = nil
            } else if closingWindow == settingsWindow {
                settingsWindow = nil
            }
        }
    }
}
