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
/// 继承自 `FileCommonData`，包含与文件路径相关的通用属性，并通过
/// SwiftData 的 `@Model` 注解支持持久化。
@Model
final class ProjectModel: FileCommonDataProtocol {
    /// 唯一标识符。用于 SwiftData 的唯一约束。
    @Attribute(.unique) var id: UUID

    // 将 path 持久化，以便可查询
    @Attribute var path: String

    /// 与该项目关联的应用程序（用于打开该文件）。
    /// 可以被更新以更换打开程序。
    var application: ApplicationModel

    /// 权重值，用于记录打开频率或排序优先级。
    /// 每次通过 `open()` 打开时会增加，默认值为 0。
    var weight: Int

    /// 根据文件路径与指定应用创建一个新的 `ProjectModel` 实例。
    /// - Parameters:
    ///   - path: 文件系统路径（绝对路径）。
    ///   - application: 默认用于打开该文件的 `ApplicationModel` 实例。
    init(path: String, application: ApplicationModel, weight: Int = 0) {
        id = UUID()
        self.path = path
        self.application = application
        self.weight = weight
    }

    /// 使用指定的（或当前的）应用程序打开此项目文件，并将权重计数加一。
    /// - Parameter newApplication: 可选的新 `ApplicationModel`，如果提供则替换当前的 `application`。
    ///
    /// 该方法会调用 `NSWorkspace.shared.open(_:withApplicationAt:configuration:)` 来启动对应的应用打开文件。
    func open(_ newApplication: ApplicationModel? = nil) {
        if let app = newApplication {
            application = app
        }
        weight += 1
        NSWorkspace.shared.open([url], withApplicationAt: application.url, configuration: NSWorkspace.OpenConfiguration())
    }
}
