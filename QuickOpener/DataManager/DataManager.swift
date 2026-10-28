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

    /// 最近一次尝试打开但已不存在的项目，用于在界面上给出提示（不自动删除）。
    @Published var missingProject: ProjectModel?

    /// 已失效（文件被移动或删除）的项目路径集合。
    /// 只在窗口显示等时机刷新一次，避免每帧对每个项目做文件系统检查。
    @Published private(set) var missingPaths: Set<String> = []

    /// 键盘导航当前选中的行索引（对应 `renderProjects` 的顺序）。
    @Published var selectedIndex: Int = 0

    /// 当前选中项；索引越界时自动钳制，列表变化后仍然安全。
    var selectedProject: ProjectModel? {
        let items = renderProjects
        guard !items.isEmpty else { return nil }
        return items[min(max(selectedIndex, 0), items.count - 1)]
    }

    /// 权重半衰期（小时）：7 天没打开过的项目，权重折半。
    private static let weightHalfLifeHours: Double = 24 * 7

    /// 排序分数：weight 按「距最近打开时间」做半衰期衰减，实现「最近常用优先」。
    /// 历史数据（lastOpenedAt 为 nil）视为很久未打开，排在后面，打开一次即回升。
    private func sortScore(for project: ProjectModel, now: Date) -> Double {
        guard let lastOpenedAt = project.lastOpenedAt else { return 0 }
        let hours = max(now.timeIntervalSince(lastOpenedAt) / 3600, 0)
        return Double(project.weight) * pow(0.5, hours / Self.weightHalfLifeHours)
    }

    /// 计算属性，返回经过过滤和排序的项目列表，用于 UI 渲染。
    /// - 按 `filterText` 过滤项目名称或路径（忽略大小写）。
    /// - 按衰减后的权重降序排序（同分时比 weight，再按路径保证顺序稳定）。
    var renderProjects: [ProjectModel] {
        var filteredProjects = projects
        if !filterText.isEmpty {
            filteredProjects = filteredProjects.filter {
                $0.name.lowercased().contains(filterText.lowercased()) ||
                    $0.path.lowercased().contains(filterText.lowercased())
            }
        }
        let now = Date()
        return filteredProjects
            .map { (project: $0, score: sortScore(for: $0, now: now)) }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                if lhs.project.weight != rhs.project.weight { return lhs.project.weight > rhs.project.weight }
                return lhs.project.path < rhs.project.path
            }
            .map { $0.project }
    }

    /// 强引用模型容器：ModelContext 不会保活它的 container，
    /// container 一旦释放，context 会被 reset，所有模型实例的 backing 都会失效。
    private let container: ModelContainer

    /// SwiftData 的模型上下文，用于持久化数据操作。
    private let modelContext: ModelContext

    /// 初始化 `DataManager`，从模型上下文加载项目和应用程序数据。
    /// - Parameter modelContext: SwiftData 的模型上下文。
    /// - 如果加载失败，初始化为空项目列表。
    /// - 确保默认的 Finder 应用程序存在于应用程序列表中。
    /// - 从 UserDefaults 加载当前应用程序路径，若无则使用默认 Finder。
    init(modelContext: ModelContext) {
        container = modelContext.container
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
        if initialApplications.isEmpty || !initialApplications.contains(where: { $0.path == ApplicationModel.defaultApplicationPath }) {
            // 每次新建实例：static 单例重复 insert 到不同 ModelContext 会出问题（如 Preview）
            let defaultApp = ApplicationModel(path: ApplicationModel.defaultApplicationPath)
            modelContext.insert(defaultApp)
            initialApplications.append(defaultApp)
            try? modelContext.save()
        }

        // 确定初始的当前应用程序
        let savedPath = UserDefaults.standard.string(forKey: "currentApplicationPath")
        let initialCurrentApp = initialApplications.first(where: { $0.path == savedPath }) ??
            initialApplications.first(where: { $0.path == ApplicationModel.defaultApplicationPath }) ??
            initialApplications[0] // 上面已保证至少插入了一个 Finder

        // 初始化所有 @Published 属性
        projects = initialProjects
        applications = initialApplications
        currentApplication = initialCurrentApp

        refreshMissingPaths()
    }

    /// 重新统计失效项目：文件检查放到后台线程，主线程只回填结果。
    /// 项目多且路径在 iCloud 上时，避免窗口显示瞬间卡住。
    func refreshMissingPaths() {
        let paths = projects.map { $0.path }
        Task { @MainActor in
            let missing = await Self.computeMissingPaths(paths)
            if missing != self.missingPaths {
                self.missingPaths = missing
            }
        }
    }

    /// 纯文件检查，nonisolated 使其跑在通用执行器而不是主线程。
    private nonisolated static func computeMissingPaths(_ paths: [String]) async -> Set<String> {
        var missing = Set<String>()
        for path in paths where !FileManager.default.fileExists(atPath: path) {
            missing.insert(path)
        }
        return missing
    }

    /// 隐藏项目窗口。打开项目成功后显式调用，不再依赖窗口失焦的副作用。
    func hideHostingWindow() {
        hostingWindow?.orderOut(nil)
    }

    /// 上下移动键盘选中项（首尾不循环）。
    func moveSelection(by delta: Int) {
        let items = renderProjects
        guard !items.isEmpty else { return }
        let current = min(max(selectedIndex, 0), items.count - 1)
        selectedIndex = min(max(current + delta, 0), items.count - 1)
    }

    /// 打开当前键盘选中项。
    func openSelected() {
        selectedProject?.open()
    }

    /// 打开指定序号的项（用于 ⌘1~9）。返回是否命中。
    @discardableResult
    func openAt(index: Int) -> Bool {
        let items = renderProjects
        guard items.indices.contains(index) else { return false }
        selectedIndex = index
        items[index].open()
        return true
    }

    /// 清空所有缓存数据，包括项目、应用程序和 UserDefaults 中的当前应用程序路径。
    /// - 删除所有持久化的 `ProjectModel` 和 `ApplicationModel`。
    /// - 重置列表为默认值（空项目列表和默认 Finder 应用程序），同时清空过滤词。
    func clearCache() {
        print("DataManager: clearCache")
        try? modelContext.delete(model: ProjectModel.self)
        try? modelContext.delete(model: ApplicationModel.self)
        try? modelContext.save()

        UserDefaults.standard.removeObject(forKey: "currentApplicationPath")
        filterText = "" // 否则重置后过滤词仍在，列表看着还是空的

        // 重建默认 Finder 并写回存储，避免内存实例与数据库不一致
        let defaultApp = ApplicationModel(path: ApplicationModel.defaultApplicationPath)
        modelContext.insert(defaultApp)
        try? modelContext.save()

        projects = []
        applications = [defaultApp]
        currentApplication = defaultApp
        missingProject = nil
        missingPaths = []
    }

    /// 记录一个已不存在的项目，交给界面提示（不静默删除，避免用户以为丢了数据）。
    func reportMissingProject(_ project: ProjectModel) {
        print("DataManager: project missing -> \(project.path)")
        missingProject = project
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
    /// - 绑定到该应用的项目会回退到 Finder，避免之后点击静默失败。
    /// - 若删除的是当前选中的应用，自动回退到 Finder。
    /// - Parameter app: 要删除的 `ApplicationModel` 实例。
    func removeApplication(_ app: ApplicationModel) {
        print("DataManager: removeApplication")
        let removedPath = app.path // 先取出：delete + save 之后访问被删模型属性会崩
        guard removedPath != ApplicationModel.defaultApplicationPath else { return }

        let fallback = applications.first(where: { $0.path == ApplicationModel.defaultApplicationPath })
            ?? ApplicationModel(path: ApplicationModel.defaultApplicationPath)

        // 先把引用该应用的项目改回 Finder，再删除应用，避免悬空 applicationPath
        let affectedProjects = projects.filter { $0.applicationPath == removedPath }
        if !affectedProjects.isEmpty {
            print("DataManager: \(affectedProjects.count) 个项目回退到 Finder")
            affectedProjects.forEach { $0.applicationPath = fallback.path }
        }

        // 先从内存数组移除（此时模型仍有效），再删库，最后才可能访问剩余对象
        let wasCurrent = currentApplication.path == removedPath
        applications = applications.filter { $0.path != removedPath }

        modelContext.delete(app)
        try? modelContext.save()

        if wasCurrent {
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

    /// 修改项目的默认打开应用并持久化。
    func setApplicationPath(_ path: String, for project: ProjectModel) {
        guard project.applicationPath != path else { return }
        project.applicationPath = path
        try? modelContext.save()
    }

    /// 直接添加一批 URL（内部/测试入口，不弹文件面板）。
    func addProjects(urls: [URL]) {
        handleProjectsPicked(urls: urls)
    }

    /// 直接添加一个应用（内部/测试入口，不弹文件面板）。
    func addApplication(path: String) {
        handleApplicationPicked(url: URL(fileURLWithPath: path))
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
        refreshMissingPaths()
    }

    // MARK: - 导入 / 导出

    /// 导入导出用的 JSON 结构（只保留路径与权重，不含安全书签）。
    struct TransferPayload: Codable {
        struct ProjectEntry: Codable {
            var path: String
            var applicationPath: String
            var weight: Int
        }

        struct ApplicationEntry: Codable {
            var path: String
        }

        var version: Int
        var exportedAt: Date
        var projects: [ProjectEntry]
        var applications: [ApplicationEntry]
    }

    /// 导出当前项目与应用列表为 JSON。
    func exportPayload() -> Data? {
        let payload = TransferPayload(
            version: 1,
            exportedAt: Date(),
            projects: projects.map {
                .init(path: $0.path, applicationPath: $0.applicationPath, weight: $0.weight)
            },
            applications: applications.map { .init(path: $0.path) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(payload)
    }

    /// 从 JSON 导入，按路径去重（已存在的跳过）。
    /// - Returns: 新增与跳过的数量；文件格式不正确时返回 nil。
    @discardableResult
    func importPayload(from data: Data) -> (added: Int, skipped: Int)? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let payload = try? decoder.decode(TransferPayload.self, from: data) else { return nil }

        for entry in payload.applications where !applications.contains(where: { $0.path == entry.path }) {
            let app = ApplicationModel(path: entry.path)
            modelContext.insert(app)
            applications.append(app)
        }

        var nextWeight = (projects.map { $0.weight }.max() ?? -1) + 1
        var added = 0
        var skipped = 0
        for entry in payload.projects {
            guard !projects.contains(where: { $0.path == entry.path }) else {
                skipped += 1
                continue
            }
            let project = ProjectModel(
                path: entry.path,
                applicationPath: entry.applicationPath,
                weight: nextWeight
            )
            modelContext.insert(project)
            projects.append(project)
            nextWeight += 1
            added += 1
        }

        try? modelContext.save()
        refreshMissingPaths()
        return (added, skipped)
    }

    /// 删除指定的项目，从持久化存储和项目列表中移除。
    /// - Parameter project: 要删除的 `ProjectModel` 实例。
    func removeProjects(_ project: ProjectModel) {
        print("DataManager: removeProjects")
        let removedPath = project.path
        modelContext.delete(project)
        try? modelContext.save()
        projects = projects.filter { $0.path != removedPath }
        missingPaths.remove(removedPath)
        ProjectInspector.shared.forget(path: removedPath) // 清掉巡检缓存，避免同一路径重新添加后显示旧数值
        if missingProject?.path == removedPath {
            missingProject = nil
        }
    }
}
