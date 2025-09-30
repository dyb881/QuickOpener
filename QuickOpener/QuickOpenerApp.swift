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
    /// 主窗口引用，存储当前打开的窗口。
    private var window: NSWindow?

    /// 菜单栏状态栏项，用于显示应用程序图标和菜单。
    private var statusItem: NSStatusItem?

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
        
        // 重置缓存
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_reset_cache", comment: "Reset cache in status menu"), action: #selector(resetCache), keyEquivalent: ""))

        // 偏好设置
        let settingsItem = NSMenuItem(title: NSLocalizedString("menu_settings", comment: "Open settings in status menu"), action: Selector(("showPreferencesWindow:")), keyEquivalent: ",")
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator()) // 分割线

        // 退出
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_quit", comment: "Quit in status menu"), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu

        // 注册全局快捷键，触发显示窗口
        KeyboardShortcuts.onKeyDown(for: .toggleProjectOpener) { [weak self] in
            self?.showWindow()
        }

        // 初次启动时显示窗口
        showWindow()
    }

    /// 退出应用程序。
    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    /// 重置数据管理器的缓存并重新显示窗口。
    @objc func resetCache() {
        print("AppDelegate: resetCache")
        QuickOpenerApp.dataManager.clearCache()
        showWindow()
    }

    /// 显示或激活窗口，若窗口不存在则创建新窗口。
    @objc func showWindow() {
        print("AppDelegate: showWindow")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let existingWindow = self.window, !existingWindow.isReleasedWhenClosed {
                self.activateWindow(existingWindow)
                positionWindowAtCursor(existingWindow)
            } else {
                self.createNewWindow()
            }
        }
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
        let mouseLocation = NSEvent.mouseLocation
        print(mouseLocation)
        let windowRect = NSRect(
            x: mouseLocation.x - 60,
            y: mouseLocation.y - 500 - 450 + 23,
            width: 300,
            height: 500
        )
        let newWindow = NSWindow(
            contentRect: windowRect,
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
        newWindow.level = .floating // 设置窗口为浮动层级
        activateWindow(newWindow)
        window = newWindow
    }

    /// 将窗口定位到鼠标光标中心附近。
    /// - Parameter window: 要定位的窗口。
    private func positionWindowAtCursor(_ window: NSWindow) {
        print("AppDelegate: positionWindowAtCursor")
        let mouseLocation = NSEvent.mouseLocation
        print(mouseLocation)
        let windowOrigin = NSPoint(
            x: mouseLocation.x - 60,
            y: mouseLocation.y - 450 + 23
        )
        window.setFrameOrigin(windowOrigin)
    }

    /// 当窗口失去激活状态时关闭窗口。
    func windowDidResignKey(_: Notification) {
        print("AppDelegate: windowDidResignKey")
        window?.close()
    }

    /// 窗口关闭时清除窗口引用。
    func windowWillClose(_: Notification) {
        print("AppDelegate: windowWillClose")
        window = nil
    }
}
