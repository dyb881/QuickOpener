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

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        do {
            projects = try modelContext.fetch(FetchDescriptor<ProjectModel>())
            applications = try modelContext.fetch(FetchDescriptor<ApplicationModel>())
        } catch {
            projects = []
            applications = []
        }
        if let path = UserDefaults.standard.string(forKey: "currentApplicationPath"), !path.isEmpty {
            currentApplication = ApplicationModel(path: path)
        } else {
            currentApplication = ApplicationModel.defaultApplication
        }
    }

    // 添加应用
    func addApplication() {
        print("DataManager: addApplication")
        let panel = NSOpenPanel()
        // 默认打开系统的 应用程序 文件夹（本地域），如果不可用回退到 /Applications
        if let appsURL = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask).first {
            panel.directoryURL = appsURL
        } else {
            panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        }
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url, !url.path.isEmpty else { return }

        let appPath = url.path
        if let existingApp = applications.first(where: { $0.path == appPath }) {
            selectApplication(existingApp)
        } else {
            let newApp = ApplicationModel(path: appPath)
            applications.append(newApp)
            modelContext.insert(newApp)
            try? modelContext.save()
            selectApplication(newApp)
        }
    }

    // 选择应用
    func selectApplication(app: ApplicationModel) {
        currentApplication = app
        UserDefaults.standard.set(currentApplication.path, forKey: "currentApplicationPath")
    }
}
