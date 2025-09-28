//
//  FileCommonData.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit

/// 非持久化的文件/应用公共基类，负责封装基于文件路径的一些常用属性。
///
/// 该类型不是 SwiftData 模型，用于被持久化模型（如 `ProjectModel`、`ApplicationModel`）继承以复用路径相关的功能。
class FileCommonData {
    /// 文件或应用的绝对路径（文件系统路径）。
    let path: String

    /// 文件 URL。根据 `path` 计算得到。
    var url: URL {
        URL(fileURLWithPath: path)
    }

    /// 文件名（不包含拓展名）。
    /// 例如对于 `/path/to/file.txt` 返回 `file`。
    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// 文件的扩展名（不包含点），如果没有扩展名则返回空字符串。
    var fileExtension: String {
        url.pathExtension
    }

    /// 用于 UI 的文件图标（基于系统的文件类型识别）。
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    /// 路径是否存在于文件系统中。
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// 初始化。
    /// - Parameter path: 文件系统路径。
    init(path: String) {
        self.path = path
    }
}
