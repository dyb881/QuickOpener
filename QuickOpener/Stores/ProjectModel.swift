//
//  ProjectModel.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import SwiftData

/// 项目数据模型，支持持久化。
@Model
final class ProjectModel: FileCommonData {
    /// 唯一标识符。
    @Attribute(.unique) var id: UUID

    /// 应用程序数据
    var application: ApplicationModel

    /// 权重
    var weight: Int

    /// 初始化
    init(path: String, application: ApplicationModel) {
        id = UUID()
        self.application = application
        weight = 0
        super.init(path: path)
    }

    /// 使用指定或现有应用程序打开文件。
    func open(with newApplication: ApplicationModel? = nil) {
        if let app = newApplication {
            application = app
        }
        weight += 1
        NSWorkspace.shared.open([url], withApplicationAt: application.url, configuration: NSWorkspace.OpenConfiguration())
    }
}
