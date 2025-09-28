//
//  FileCommonData.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import Foundation

/// 协议：提供基于持久化 `path` 的通用计算属性。
protocol FileCommonDataProtocol {
    var path: String { get } // 由模型持久化存储提供
}

extension FileCommonDataProtocol {
    var url: URL {
        URL(fileURLWithPath: path)
    }

    var name: String {
        url.deletingPathExtension().lastPathComponent
    }

    var fileExtension: String {
        url.pathExtension
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    var exists: Bool {
        FileManager.default.fileExists(atPath: path)
    }
}
