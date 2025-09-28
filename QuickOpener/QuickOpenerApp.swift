//
//  QuickOpenerApp.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import KeyboardShortcuts
import SwiftUI

// 定义快捷键名称
extension KeyboardShortcuts.Name {
    static let toggleProjectOpener = Self("toggleProjectOpener", default: .init(.z, modifiers: .option))
}

// 主应用程序入口，设置无默认窗口，使用菜单栏图标和全局快捷键
@main
struct QuickOpenerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ApplicationModel.self,
            ProjectModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

// 应用程序代理，管理菜单栏图标、全局快捷键和窗口
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow? // 主窗口引用
    private var statusItem: NSStatusItem? // 菜单栏图标

    // 应用程序启动完成时调用
    func applicationDidFinishLaunching(_: Notification) {
        // 设置菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            let image = NSImage(named: "MenuIcon")
            image?.size = NSSize(width: 18, height: 18) // 设置为菜单栏合适大小
            button.image = image
        }

        // 创建菜单
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "显示窗口", action: #selector(showWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "重置缓存", action: #selector(resetCache), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: ""))
        statusItem?.menu = menu

        // 注册全局快捷键
        KeyboardShortcuts.onKeyDown(for: .toggleProjectOpener) { [weak self] in
            self?.showWindow()
        }

        // 初次打开窗口
        showWindow()
    }

    // 退出应用程序
    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // 重置缓存
    @objc func resetCache() {
        showWindow()
    }

    // 显示或激活窗口
    @objc func showWindow() {
        print("showWindow")
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

    // 激活现有窗口并调整位置
    private func activateWindow(_ window: NSWindow) {
        print("activateWindow")
        window.makeKeyAndOrderFront(nil) // 确保窗口成为主窗口并显示
        NSApp.activate(ignoringOtherApps: true) // 激活应用程序
    }

    // 创建新窗口并显示
    private func createNewWindow() {
        print("createNewWindow")
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
        let hostingController = NSHostingController(rootView: ContentView())
        newWindow.contentViewController = hostingController
        newWindow.collectionBehavior = [.managed, .moveToActiveSpace]
        newWindow.delegate = self
        newWindow.isReleasedWhenClosed = false
        newWindow.isMovableByWindowBackground = true
        newWindow.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        newWindow.standardWindowButton(.zoomButton)?.isEnabled = false
        newWindow.level = .floating
        activateWindow(newWindow)
        window = newWindow
    }

    // 将窗口定位到鼠标光标中心
    private func positionWindowAtCursor(_ window: NSWindow) {
        print("positionWindowAtCursor")
        let mouseLocation = NSEvent.mouseLocation
        print(mouseLocation)
        let windowOrigin = NSPoint(
            x: mouseLocation.x - 60,
            y: mouseLocation.y - 450 + 23
        )
        window.setFrameOrigin(windowOrigin)
    }

    // 窗口失去激活状态
    func windowDidResignKey(_: Notification) {
        print("windowDidResignKey")
        window?.close()
    }

    // 窗口关闭时清除引用
    func windowWillClose(_: Notification) {
        print("windowWillClose")
        window = nil
    }
}
