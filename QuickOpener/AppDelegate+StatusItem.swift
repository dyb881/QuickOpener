//
//  AppDelegate+StatusItem.swift
//  QuickOpener
//
//  菜单栏图标、菜单与设置窗口（从 AppDelegate 拆出）。
//

import AppKit
import SwiftData
import SwiftUI

extension AppDelegate {
    /// 构建菜单栏图标与菜单。
    func setupStatusItem() {
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

        menu.addItem(NSMenuItem.separator())

        // 显示设置
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_settings", comment: "Open settings in status menu"), action: #selector(showSetting), keyEquivalent: ""))

        // 重置缓存
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_reset_cache", comment: "Reset cache in status menu"), action: #selector(resetCache), keyEquivalent: ""))

        menu.addItem(NSMenuItem.separator())

        // 退出
        menu.addItem(NSMenuItem(title: NSLocalizedString("menu_quit", comment: "Quit in status menu"), action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
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
}
