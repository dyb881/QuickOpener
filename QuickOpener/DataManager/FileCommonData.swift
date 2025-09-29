//
//  FileCommonData.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import Foundation

/// 协议：定义基于持久化路径的通用文件属性访问接口。
protocol FileCommonDataProtocol {
    /// 文件的持久化存储路径。
    var path: String { get }
}

/// 协议扩展：为符合 FileCommonDataProtocol 的类型提供基于路径的计算属性。
extension FileCommonDataProtocol {
    /// 文件的 URL 表示形式，基于路径构造。
    var url: URL {
        URL(fileURLWithPath: path)
    }

    /// 文件名（不含扩展名），从 URL 中提取。
    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    /// 文件扩展名，从 URL 中提取。
    var fileExtension: String {
        url.pathExtension
    }

    /// 文件的图标，使用 NSWorkspace 从路径获取。
    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    /// 检查文件是否存在，使用 FileManager 验证路径。
    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
