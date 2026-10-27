//
//  AppDelegate+Keyboard.swift
//  QuickOpener
//
//  窗口内键盘监听与标题栏快捷键提示（从 AppDelegate 拆出）。
//

import AppKit
import KeyboardShortcuts

extension AppDelegate {
    /// 监听快捷键变化，同步刷新标题栏提示。
    func setupShortcutObserver() {
        shortcutObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("KeyboardShortcuts_shortcutByNameDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // queue: .main 保证在主线程，直接断言到 MainActor，避免 Task 捕获警告
            MainActor.assumeIsolated {
                self?.updateShortcutLabel()
            }
        }
    }

    /// 刷新标题栏上的快捷键提示，跟随设置里录制的结果。
    @MainActor
    func updateShortcutLabel() {
        let shortcut = KeyboardShortcuts.getShortcut(for: .toggleProjectOpener)
        shortcutLabel?.stringValue = shortcut?.description ?? ""
    }

    /// 窗口内的键盘监听：ESC 隐藏、↑↓ 选择、回车打开选中项、⌘1~9 直选。
    func setupKeyMonitor() {
        // 先移除现有的监视器
        removeKeyMonitor()

        // 添加新的本地事件监视器
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            // 有模态面板（NSOpenPanel / NSAlert）时，把按键交还给面板自己处理
            guard NSApp.modalWindow == nil else { return event }
            // 只在项目窗口持有键盘焦点时接管，避免影响设置窗口等输入
            guard let window = self.window, window.isKeyWindow, window.isVisible else { return event }
            return self.handleKeyEvent(event, in: window)
        }
    }

    /// 移除键盘监听
    func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    /// 处理单个按键，返回 nil 表示事件已被消费。
    private func handleKeyEvent(_ event: NSEvent, in window: NSWindow) -> NSEvent? {
        let manager = QuickOpenerApp.dataManager

        switch event.keyCode {
        case 53: // ESC
            hideWindow(window)
            return nil
        case 125: // ↓
            manager.moveSelection(by: 1)
            return nil
        case 126: // ↑
            manager.moveSelection(by: -1)
            return nil
        case 36, 76: // Return / Enter
            manager.openSelected()
            return nil
        default:
            break
        }

        // ⌘1~9 直接打开对应序号的项
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command),
           flags.intersection([.shift, .option, .control]).isEmpty,
           let characters = event.charactersIgnoringModifiers,
           let number = Int(characters), (1 ... 9).contains(number),
           manager.openAt(index: number - 1) {
            return nil
        }

        return event
    }
}
