//
//  Stores.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import Observation

@Observable class Stores {
    
    // 项目列表
    var projects: [ProjectItem] { didSet { CacheData.set(key: "projects", data: projects) } }

    // 应用列表
    var applications: [ApplicationItem] { didSet { CacheData.set(key: "applications", data: applications) } }

    // 当前选中应用
    var currentApplication: ApplicationItem { didSet { CacheData.set(key: "currentApplication", data: currentApplication) } }

    // 过滤文本
    var filterText: String = ""
    
}
