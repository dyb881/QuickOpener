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
    /// 如果文件不存在，将从数据管理器中移除该项目。
    /// 调用 `NSWorkspace.shared.open(_:withApplicationAt:configuration:)` 启动应用程序打开文件。
    /// - Parameter newApplicationPath: 可选参数，用于替换当前关联的 `ApplicationModel`。
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

        // 优先使用 bookmarkURL
        let urlToUse = bookmarkURL ?? url
        
        // 开始安全作用域访问
        var accessGranted = false
        if let bookmarkURL = bookmarkURL {
            accessGranted = bookmarkURL.startAccessingSecurityScopedResource()
            print("安全作用域访问: \(accessGranted ? "已授权" : "未授权") - \(bookmarkURL.path)")
        }

        // 使用 NSWorkspace 打开文件
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        
        NSWorkspace.shared.open([urlToUse], withApplicationAt: applicationUrl, configuration: configuration) { [weak self] app, error in
            if let error = error {
                print("打开文件失败: \(error.localizedDescription)")
            } else {
                print("文件打开成功")
            }
            
            // 在打开完成后停止安全作用域访问
            if accessGranted, let bookmarkURL = self?.bookmarkURL {
                bookmarkURL.stopAccessingSecurityScopedResource()
                print("安全作用域访问已停止")
            }
        }
    }
}
