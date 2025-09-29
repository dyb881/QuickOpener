//
//  ApplicationModel.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import SwiftData

/// 表示一个可持久化保存的“应用程序”条目，包含应用程序路径及相关元数据。
///
/// 继承自 `FileCommonDataProtocol`，提供基于路径的通用属性（如 URL、文件名、图标等），
/// 并通过 SwiftData 的 `@Model` 注解支持数据持久化存储。
@Model
final class ApplicationModel: FileCommonDataProtocol {
    /// 唯一标识符，用于 SwiftData 的唯一约束，确保每个应用程序实例唯一。
    @Attribute(.unique) var id: UUID

    /// 应用程序的绝对路径，持久化存储以支持查询和文件操作。
    @Attribute var path: String

    /// 默认应用程序模型，指向 Finder，作为默认的文件打开程序。
    static let defaultApplication = ApplicationModel(path: "/System/Library/CoreServices/Finder.app")

    /// 初始化一个 `ApplicationModel` 实例，指定应用程序路径。
    /// - Parameter path: 应用程序在文件系统中的绝对路径（例如 .app 文件夹路径）。
    init(path: String) {
        id = UUID()
        self.path = path
    }
}
