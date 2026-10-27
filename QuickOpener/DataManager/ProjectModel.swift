//
//  ProjectModel.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import SwiftData

/// 表示一个可持久化保存的“项目”或文件条目。
///
/// 继承自 `FileCommonDataProtocol`，提供基于文件路径的通用属性（如 URL、文件名、图标等），
/// 并通过 SwiftData 的 `@Model` 注解支持数据持久化存储。
@Model
final class ProjectModel: FileCommonDataProtocol {
    /// 唯一标识符，用于 SwiftData 的唯一约束，确保每个项目实例唯一。
    @Attribute(.unique) var id: UUID

    /// 文件的绝对路径，持久化存储以支持查询和文件操作。
    @Attribute var path: String

    /// 关联应用程序的路径，用于标识打开文件的应用程序。
    var applicationPath: String

    /// 权重值，用于记录打开频率或排序优先级，默认为 0，每次调用 `open(_:)` 时递增。
    var weight: Int

    /// 最近一次打开（或添加）时间，用于按半衰期衰减排序；历史数据为 nil。
    var lastOpenedAt: Date?

    /// 安全书签数据，用于存储安全访问书签。
    var bookmarkData: Data?

    /// 初始化一个新的 `ProjectModel` 实例，关联文件路径和默认打开应用程序。
    /// - Parameters:
    ///   - path: 文件的绝对路径（字符串）。
    ///   - application: 默认用于打开文件的 `ApplicationModel` 实例。
    ///   - weight: 初始权重值，默认为 0，用于记录打开频率。
    init(path: String, applicationPath: String, weight: Int = 0) {
        id = UUID()
        self.path = path
        self.applicationPath = applicationPath
        self.weight = weight
        lastOpenedAt = Date() // 新添加的项目视为「刚刚打开」，保证排在列表前面
        let url = URL(fileURLWithPath: path)
        bookmarkData = try? url.bookmarkData(options: .withSecurityScope)
    }

    /// 关联应用程序的URL
    var applicationUrl: URL {
        URL(fileURLWithPath: applicationPath)
    }

    /// 关联应用程序的文件名（不含扩展名），从 URL 中提取。
    var applicationName: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// 关联应用程序的图标，使用 NSWorkspace 从路径获取。
    var applicationIcon: NSImage {
        NSWorkspace.shared.icon(forFile: applicationPath)
    }

    /// 从书签数据解析的安全 URL。
    var bookmarkURL: URL? {
        guard let data = bookmarkData else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
            if isStale {
                // 可选：更新书签数据
                bookmarkData = try? url.bookmarkData(options: .withSecurityScope)
            }
            return url
        } catch {
            return nil
        }
    }

    /// 使用指定或当前关联的应用程序打开项目文件，并增加权重计数。
    ///
    /// 文件不存在时不再静默删除项目，而是交给界面提示，避免用户以为数据丢了。
    /// 调用 `NSWorkspace.shared.open(_:withApplicationAt:configuration:)` 启动应用程序打开文件。
    /// - Parameter newApplicationPath: 可选参数，用于替换当前关联的 `ApplicationModel`。
    @MainActor
    func open(_ newApplicationPath: String? = nil) {
        // 文件不存在：提示用户，保留记录（不再静默移除）
        guard exists else {
            QuickOpenerApp.dataManager.reportMissingProject(self)
            return
        }

        // 如果提供了新应用程序路径，则更新
        if let path = newApplicationPath {
            applicationPath = path
        }

        // 增加权重计数并记录最近打开时间
        weight += 1
        lastOpenedAt = Date()

        // 书签只解析一次，start / stop 使用同一个 URL 对象
        let scopedURL = bookmarkURL
        let urlToUse = scopedURL ?? url
        let accessGranted = scopedURL?.startAccessingSecurityScopedResource() ?? false
        print("安全作用域访问: \(accessGranted ? "已授权" : "未授权") - \(urlToUse.path)")

        // 使用 NSWorkspace 打开文件
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        NSWorkspace.shared.open([urlToUse], withApplicationAt: applicationUrl, configuration: configuration) { _, error in
            if let error = error {
                print("打开文件失败: \(error.localizedDescription)")
            } else {
                print("文件打开成功")
                // 成功后才隐藏窗口；失败时留着窗口让用户重试
                Task { @MainActor in
                    QuickOpenerApp.dataManager.hideHostingWindow()
                }
            }

            // 在打开完成后停止安全作用域访问
            if accessGranted, let scopedURL = scopedURL {
                scopedURL.stopAccessingSecurityScopedResource()
                print("安全作用域访问已停止")
            }
        }
    }
}
