//
//  ApplicationModel.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import SwiftData

/// 表示一个可保存的“应用程序”条目，包含用于打开文件的程序路径和相关元数据。
@Model
final class ApplicationModel: FileCommonData {
    /// 默认的应用模型，指向 Finder（作为默认的文件打开程序）。
    static let defaultApplication = ApplicationModel(path: "/System/Library/CoreServices/Finder.app")

    /// 唯一标识符，用于 SwiftData 的唯一约束。
    @Attribute(.unique) var id: UUID

    /// 初始化一个 `ApplicationModel`。
    /// - Parameter path: 应用在文件系统中的路径（例如 Finder 的 .app 路径）。
    override init(path: String) {
        id = UUID()
        super.init(path: path)
    }
}
