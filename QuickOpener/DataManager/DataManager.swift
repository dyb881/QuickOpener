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
    /// - 如果加载失败，初始化为空项目列表和默认 Finder 应用程序。
    /// - 从 UserDefaults 加载当前应用程序路径，若无则使用默认 Finder。
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        do {
            projects = try modelContext.fetch(FetchDescriptor<ProjectModel>())
            applications = try modelContext.fetch(FetchDescriptor<ApplicationModel>())
        } catch {
            projects = []
            applications = [ApplicationModel.defaultApplication]
            modelContext.insert(ApplicationModel.defaultApplication)
            try? modelContext.save()
        }
        if let path = UserDefaults.standard.string(forKey: "currentApplicationPath"), !path.isEmpty {
            currentApplication = ApplicationModel(path: path)
        } else {
            currentApplication = ApplicationModel.defaultApplication
        }
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

        guard panel.runModal() == .OK, let url = panel.url else { return }

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
    /// - Parameter app: 要删除的 `ApplicationModel` 实例。
    func removeApplication(_ app: ApplicationModel) {
        print("DataManager: removeApplication")
        modelContext.delete(app)
        try? modelContext.save()
        applications = applications.filter { $0 != app }
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

        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }

        let existingPaths = Set(projects.map { $0.path })

        let newProjects = panel.urls
            .filter { !existingPaths.contains($0.path) }
            .map { ProjectModel(
                path: $0.path,
                application: currentApplication,
                weight: projects.isEmpty ? 0 : projects[0].weight + 1
            ) }

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
