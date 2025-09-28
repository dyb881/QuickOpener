//
//  Stores.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import Observation
import SwiftData

/// 应用程序的持久化存取服务。
///
/// 该类封装对 `ModelContext` 的基础操作（查询、插入、删除和保存），
/// 使上层 UI 或业务逻辑可以更方便地对 `ProjectModel` / `ApplicationModel` 进行读写。
@Observable class Stores {
    /// 注入的 SwiftData 上下文，用于执行查询/保存等操作。
    private let modelContext: ModelContext

    /// 使用指定的 `ModelContext` 初始化 Stores。
    /// - Parameter modelContext: 用于持久化操作的上下文。
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Queries

    /// 获取所有项目并按 `weight` 降序返回（最近使用/权重更高的排在前面）。
    /// - Returns: 按权重降序排列的 `ProjectModel` 数组。
    func fetchAllProjects() -> [ProjectModel] {
        let descriptor = FetchDescriptor<ProjectModel>()
        let list = modelContext.fetch(descriptor)
        return list.sorted { $0.weight > $1.weight }
    }

    /// 获取所有已保存的应用程序模型。
    func fetchAllApplications() -> [ApplicationModel] {
        let descriptor = FetchDescriptor<ApplicationModel>()
        return modelContext.fetch(descriptor)
    }

    // MARK: - Inserts / Deletes / Saves

    /// 创建并保存一个新的 `ApplicationModel`。
    /// - Parameter path: 应用的文件系统路径（例如 Finder 的路径）。
    /// - Returns: 新创建并已插入到 context 的 `ApplicationModel`。
    /// - Throws: 当 `ModelContext.save()` 失败时将抛出异常。
    @discardableResult
    func addApplication(path: String) throws -> ApplicationModel {
        let app = ApplicationModel(path: path)
        modelContext.insert(app)
        try modelContext.save()
        return app
    }

    /// 创建并保存一个新的 `ProjectModel`。
    /// - Parameters:
    ///   - path: 项目/文件的路径。
    ///   - application: 关联的启动应用对象。
    /// - Returns: 新创建的 `ProjectModel`。
    /// - Throws: 当保存失败时抛出异常。
    @discardableResult
    func addProject(path: String, application: ApplicationModel) throws -> ProjectModel {
        let project = ProjectModel(path: path, application: application)
        modelContext.insert(project)
        try modelContext.save()
        return project
    }

    /// 删除指定的项目并保存变更。
    /// - Throws: 当保存失败时抛出异常。
    func deleteProject(_ project: ProjectModel) throws {
        modelContext.delete(project)
        try modelContext.save()
    }

    /// 删除指定的应用并保存变更。
    /// - Throws: 当保存失败时抛出异常。
    func deleteApplication(_ app: ApplicationModel) throws {
        modelContext.delete(app)
        try modelContext.save()
    }

    // MARK: - Helpers

    /// 根据路径查找已存在的应用模型（路径完全匹配）。
    /// - Parameter path: 要查找的文件系统路径。
    func application(withPath path: String) -> ApplicationModel? {
        let predicate = NSPredicate(format: "path == %@", path)
        let descriptor = FetchDescriptor<ApplicationModel>(predicate: predicate)
        return modelContext.fetch(descriptor).first
    }
}
