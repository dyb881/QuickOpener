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

class DataManager: ObservableObject {
    @Published var projects: [ProjectModel]
    @Published var applications: [ApplicationModel]
    @Published var currentApplication: ApplicationModel
    @Published var filterText: String = ""

    // 渲染列表数据
    var renderProjects: [ProjectModel] {
        var filteredProjects = projects
        if !filterText.isEmpty {
            filteredProjects = filteredProjects.filter { $0.name.lowercased().contains(filterText.lowercased()) || $0.path.lowercased().contains(filterText.lowercased()) }
        }
        return filteredProjects.sorted { $0.weight > $1.weight }
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        do {
            projects = try modelContext.fetch(FetchDescriptor<ProjectModel>())
            applications = try modelContext.fetch(FetchDescriptor<ApplicationModel>())
        } catch {
            projects = []
            applications = [ApplicationModel.defaultApplication]
        }
        if let path = UserDefaults.standard.string(forKey: "currentApplicationPath"), !path.isEmpty {
            currentApplication = ApplicationModel(path: path)
        } else {
            currentApplication = ApplicationModel.defaultApplication
        }
    }

    // 清空所有缓存
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

    // 添加应用
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

    // 删除应用
    func removeApplication(_ app: ApplicationModel) {
        print("DataManager: removeApplication")
        modelContext.delete(app)
        try? modelContext.save()
        applications = applications.filter { $0 != app }
    }

    // 选择应用
    func selectApplication(_ app: ApplicationModel) {
        print("DataManager: selectApplication -> \(app.path)")
        currentApplication = app
        UserDefaults.standard.set(currentApplication.path, forKey: "currentApplicationPath")
    }

    // 添加项目
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

    // 删除项目
    func removeProjects(_ project: ProjectModel) {
        print("DataManager: removeProjects")
        modelContext.delete(project)
        try? modelContext.save()
        projects = projects.filter { $0 != project }
    }
}
