//
//  DataManager.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import Combine
import SwiftData
internal import UniformTypeIdentifiers

/// 数据管理类，负责管理项目和应用程序的数据，处理数据持久化、选择和过滤逻辑。
@MainActor
class DataManager: ObservableObject {
    /// 项目列表，存储所有 `ProjectModel` 实例，发布更改以触发 UI 更新。
    @Published var projects: [ProjectModel]

    /// 应用程序列表，存储所有 `ApplicationModel` 实例，发布更改以触发 UI 更新。
    @Published var applications: [ApplicationModel]

    /// 当前选中的应用程序，用于打开项目文件，发布更改以触发 UI 更新。
    @Published var currentApplication: ApplicationModel

    /// 过滤文本，用于筛选项目列表。
    @Published var filterText: String = ""

    /// 托管窗口引用，用于 NSOpenPanel 的 Sheet 模态展示。
    /// 由 AppDelegate 在创建窗口时设置。
    weak var hostingWindow: NSWindow?

    /// 计算属性，返回经过过滤和排序的项目列表，用于 UI 渲染。
    /// - 按 `filterText` 过滤项目名称或路径（忽略大小写）。
    /// - 按权重（`weight`）降序排序。
    var renderProjects: [ProjectModel] {
        var filteredProjects = projects
        if !filterText.isEmpty {
            filteredProjects = filteredProjects.filter {
                $0.name.lowercased().contains(filterText.lowercased()) ||
                    $0.path.lowercased().contains(filterText.lowercased())
            }
        }
        return filteredProjects.sorted { $0.weight > $1.weight }
    }

    /// SwiftData 的模型上下文，用于持久化数据操作。
    private let modelContext: ModelContext

    /// 初始化 `DataManager`，从模型上下文加载项目和应用程序数据。
    /// - Parameter modelContext: SwiftData 的模型上下文。
    /// - 如果加载失败，初始化为空项目列表。
    /// - 确保默认的 Finder 应用程序存在于应用程序列表中。
    /// - 从 UserDefaults 加载当前应用程序路径，若无则使用默认 Finder。
    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // 初始化存储属性
        var initialProjects: [ProjectModel] = []
        var initialApplications: [ApplicationModel] = []

        // 从数据库加载数据
        do {
            initialProjects = try modelContext.fetch(FetchDescriptor<ProjectModel>())
            initialApplications = try modelContext.fetch(FetchDescriptor<ApplicationModel>())
        } catch {
            print("Error fetching data: \(error)")
        }

        // 确保默认的 Finder 应用程序存在
        if initialApplications.isEmpty || !initialApplications.contains(where: { $0.path == ApplicationModel.defaultApplication.path }) {
            let defaultApp = ApplicationModel.defaultApplication
            modelContext.insert(defaultApp)
            initialApplications.append(defaultApp)
            try? modelContext.save()
        }

        // 确定初始的当前应用程序
        let savedPath = UserDefaults.standard.string(forKey: "currentApplicationPath")
        let initialCurrentApp = initialApplications.first(where: { $0.path == savedPath }) ??
            initialApplications.first(where: { $0.path == ApplicationModel.defaultApplication.path }) ??
            ApplicationModel.defaultApplication

        // 初始化所有 @Published 属性
        projects = initialProjects
        applications = initialApplications
        currentApplication = initialCurrentApp
    }

    /// 清空所有缓存数据，包括项目、应用程序和 UserDefaults 中的当前应用程序路径。
    /// - 删除所有持久化的 `ProjectModel` 和 `ApplicationModel`。
    /// - 重置列表为默认值（空项目列表和默认 Finder 应用程序）。
    func clearCache() {
        print("DataManager: clearCache")
        try? modelContext.delete(model: ProjectModel.self)
        try? modelContext.delete(model: ApplicationModel.self)
        try? modelContext.save()

        UserDefaults.standard.removeObject(forKey: "currentApplicationPath")

        projects = []
        applications = [ApplicationModel.defaultApplication]
        currentApplication = ApplicationModel.defaultApplication
    }

    /// 添加新应用程序，通过文件选择面板选择 .app 文件。
    /// - 如果应用程序已存在，则选中该应用程序。
    /// - 否则创建新 `ApplicationModel`，保存到持久化存储并添加到列表。
    func addApplication() {
        print("DataManager: addApplication")
        let panel = NSOpenPanel()
        panel.directoryURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first ?? URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        if hostingWindow == nil {
            print("DataManager: hostingWindow is nil, falling back to runModal")
        } else if hostingWindow!.isReleasedWhenClosed {
            print("DataManager: hostingWindow isReleasedWhenClosed=true, falling back to runModal")
        }

        // 使用 runModal 避免 NSPanel + Sheet 的兼容问题
        defer { restoreHostingWindowFocus() }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        print("DataManager: runModal completed OK, url=\(url.path)")
        handleApplicationPicked(url: url)
    }

    /// 把键盘焦点还给项目窗口：模态面板关闭后项目窗口通常已不是 key window，
    /// 不恢复的话 ESC 与文本输入都会失效。
    private func restoreHostingWindowFocus() {
        hostingWindow?.makeKeyAndOrderFront(nil)
    }

    /// 处理用户选择的应用程序 URL（公共逻辑，被 Sheet 和 runModal 两种路径共用）
    private func handleApplicationPicked(url: URL) {
        let appPath = url.path
        if let existingApp = applications.first(where: { $0.path == appPath }) {
            selectApplication(existingApp)
        } else {
            let newApp = ApplicationModel(path: appPath)
            modelContext.insert(newApp)
            try? modelContext.save()
            applications.append(newApp)
            selectApplication(newApp)
        }
    }

    /// 删除指定的应用程序，从持久化存储和列表中移除。
    /// - 内置的 Finder 不允许删除。
    /// - 若删除的是当前选中的应用，自动回退到 Finder。
    /// - Parameter app: 要删除的 `ApplicationModel` 实例。
    func removeApplication(_ app: ApplicationModel) {
        print("DataManager: removeApplication")
        guard app.path != ApplicationModel.defaultApplication.path else { return }
        modelContext.delete(app)
        try? modelContext.save()
        applications = applications.filter { $0.path != app.path }

        if currentApplication.path == app.path {
            let fallback = applications.first(where: { $0.path == ApplicationModel.defaultApplication.path })
                ?? ApplicationModel.defaultApplication
            selectApplication(fallback)
        }
    }

    /// 选择指定的应用程序作为当前应用程序，并保存路径到 UserDefaults。
    /// - Parameter app: 要选中的 `ApplicationModel` 实例。
    func selectApplication(_ app: ApplicationModel) {
        print("DataManager: selectApplication -> \(app.path)")
        currentApplication = app
        UserDefaults.standard.set(currentApplication.path, forKey: "currentApplicationPath")
    }

    /// 添加新项目，通过文件选择面板选择文件或文件夹。
    /// - 过滤已存在的路径，避免重复添加。
    /// - 为新项目设置当前应用程序和新权重（基于现有最大权重加 1）。
    /// - 保存到持久化存储并添加到项目列表。
    func addProjects() {
        print("DataManager: addProjects")
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        if hostingWindow == nil {
            print("DataManager: hostingWindow is nil, falling back to runModal")
        } else if hostingWindow!.isReleasedWhenClosed {
            print("DataManager: hostingWindow isReleasedWhenClosed=true, falling back to runModal")
        }

        // 使用 runModal 避免 NSPanel + Sheet 的兼容问题
        defer { restoreHostingWindowFocus() }
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        print("DataManager: runModal completed OK, url count=\(panel.urls.count)")
        handleProjectsPicked(urls: panel.urls)
    }

    /// 处理用户选择的项目 URL 列表（公共逻辑，被 Sheet 和 runModal 两种路径共用）
    private func handleProjectsPicked(urls: [URL]) {
        let existingPaths = Set(projects.map { $0.path })
        // 以现有最大权重为基准递增，保证新项目一定排在列表最上方且批量添加顺序确定
        var nextWeight = (projects.map { $0.weight }.max() ?? -1) + 1

        var newProjects: [ProjectModel] = []
        for url in urls where !existingPaths.contains(url.path) {
            newProjects.append(ProjectModel(
                path: url.path,
                applicationPath: currentApplication.path,
                weight: nextWeight
            ))
            nextWeight += 1
        }

        guard !newProjects.isEmpty else { return }

        newProjects.forEach { modelContext.insert($0) }
        try? modelContext.save()
        projects.append(contentsOf: newProjects)
    }

    /// 删除指定的项目，从持久化存储和项目列表中移除。
    /// - Parameter project: 要删除的 `ProjectModel` 实例。
    func removeProjects(_ project: ProjectModel) {
        print("DataManager: removeProjects")
        modelContext.delete(project)
        try? modelContext.save()
        projects = projects.filter { $0 != project }
    }
}
