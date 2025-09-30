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

    /// 使用指定或当前关联的应用程序打开项目文件，并增加权重计数。
    ///
    /// 如果文件不存在，将从数据管理器中移除该项目。
    /// 调用 `NSWorkspace.shared.open(_:withApplicationAt:configuration:)` 启动应用程序打开文件。
    /// - Parameter newApplication: 可选参数，用于替换当前关联的 `ApplicationModel`。
    func open(_ newApplicationPath: String? = nil) {
        // 检查文件是否存在，不存在则移除项目
        if !exists {
            QuickOpenerApp.dataManager.removeProjects(self)
            return
        }

        // 如果提供了新应用程序路径，则更新
        if let path = newApplicationPath {
            applicationPath = path
        }

        // 增加权重计数
        weight += 1

        // 使用 NSWorkspace 打开文件
        NSWorkspace.shared.open([url], withApplicationAt: applicationUrl, configuration: NSWorkspace.OpenConfiguration())
    }
}
