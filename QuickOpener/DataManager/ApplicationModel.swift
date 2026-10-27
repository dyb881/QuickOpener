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

    /// 默认打开方式（Finder）的路径。
    /// 这里用路径常量而不是静态 `@Model` 实例：模型实例与 ModelContext 绑定，
    /// 跨 context 复用同一个共享实例（尤其单元测试里每个用例一个内存库）会因 backing 失效而崩溃。
    static let defaultApplicationPath = "/System/Library/CoreServices/Finder.app"

    /// 初始化一个 `ApplicationModel` 实例，指定应用程序路径。
    /// - Parameter path: 应用程序在文件系统中的绝对路径（例如 .app 文件夹路径）。
    init(path: String) {
        id = UUID()
        self.path = path
    }
}
