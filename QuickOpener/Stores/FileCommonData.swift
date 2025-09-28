//
//  FileCommonData.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit

/// 文件公共属性基类，非持久化。
class FileCommonData {
    /// 文件路径。
    let path: String

    /// 文件 URL。
    var url: URL {
        URL(fileURLWithPath: path)
    }

    /// 文件名（无扩展名）。
    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// 文件图标。
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    /// 路径是否存在。
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }

    /// 初始化。
    init(path: String) {
        self.path = path
    }
}
