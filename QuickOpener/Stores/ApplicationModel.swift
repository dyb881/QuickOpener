//
//  ApplicationModel.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import SwiftData

/// 应用程序数据模型，支持持久化。
@Model
final class ApplicationModel: FileCommonData {
    /// 默认数据
    static let defaultApplication = ApplicationModel(path: "/System/Library/CoreServices/Finder.app")

    /// 唯一标识符。
    @Attribute(.unique) var id: UUID

    /// 初始化。
    override init(path: String) {
        id = UUID()
        super.init(path: path)
    }
}
