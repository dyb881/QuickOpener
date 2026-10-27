//
//  ContentView.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import SwiftData
import SwiftUI

/// 主视图，显示项目列表和应用程序选择控件，用于管理文件和打开方式。
struct ContentView: View {
    /// 环境对象，引用 `DataManager` 来管理项目和应用程序数据。
    @EnvironmentObject private var dataManager: DataManager

    /// 状态变量，跟踪当前鼠标悬停的项目。
    @State private var hoveredProject: ProjectModel?

    /// 视图主体，包含头部控件和项目列表，设置固定窗口大小。
    var body: some View {
        VStack {
            headerControls
                .padding([.horizontal, .top])
            projectsList
        }
        .frame(width: 300, height: 500)
        .alert(
            LocalizedStringKey("project_missing_title"),
            isPresented: Binding(
                get: { dataManager.missingProject != nil },
                set: { if !$0 { dataManager.missingProject = nil } }
            ),
            presenting: dataManager.missingProject
        ) { _ in
            Button(role: .cancel) {} label: { Text(verbatim: "OK") }
        } message: { project in
            Text(verbatim: project.path)
        }
    }

    /// 头部控件，包含过滤文本输入框和添加项目按钮。
    private var headerControls: some View {
        HStack {
            TextField(LocalizedStringKey("filter_projects"), text: $dataManager.filterText) // 输入框，用于过滤项目列表
            addProjectButton // 添加项目和应用程序的菜单按钮
        }
    }

    /// 创建应用程序菜单项，显示应用程序图标和名称。
    /// - Parameters:
    ///   - app: 要显示的 `ApplicationModel` 实例。
    ///   - action: 按钮点击时的操作。
    /// - Returns: 包含图标和名称的菜单项视图。
    private func appButton(_ app: ApplicationModel, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(nsImage: app.icon)
            Text(app.name)
        }
    }

    /// 添加项目 / 管理应用的菜单按钮。
    ///
    /// 不使用 `Menu` 的 `primaryAction`：macOS 上 primaryAction 会接管点击，
    /// 展开菜单降级为点击右侧极窄的指示器，导致「切换应用 / 添加应用」几乎无法触达。
    private var addProjectButton: some View {
        Menu {
            Button {
                dataManager.addProjects() // 选择文件或文件夹添加到列表
            } label: {
                Label(LocalizedStringKey("add_projects"), systemImage: "plus.square.on.square")
            }

            Divider()

            Text(LocalizedStringKey("menu_current_application")) // 当前使用的应用（仅展示）
            Button {
                // 当前应用，仅作状态展示
            } label: {
                Image(nsImage: dataManager.currentApplication.icon)
                Text(dataManager.currentApplication.name)
            }
            .disabled(true)

            if dataManager.applications.count >= 2 {
                Text(LocalizedStringKey("menu_available_applications")) // 列出其他可用应用程序
                ForEach(dataManager.applications.filter { $0.path != dataManager.currentApplication.path }, id: \.path) { app in
                    appButton(app) {
                        dataManager.selectApplication(app) // 选择其他应用程序
                    }
                }
            }

            Divider()

            Button {
                dataManager.addApplication() // 打开面板添加新应用程序
            } label: {
                Label(LocalizedStringKey("add_application"), systemImage: "app.badge.plus")
            }

            if dataManager.applications.contains(where: { $0.path != ApplicationModel.defaultApplication.path }) {
                Menu {
                    ForEach(dataManager.applications.filter { $0.path != ApplicationModel.defaultApplication.path }, id: \.path) { app in
                        Button(role: .destructive) {
                            dataManager.removeApplication(app) // 删除已添加的应用（内置 Finder 不可删）
                        } label: {
                            Image(nsImage: app.icon)
                            Text(app.name)
                        }
                    }
                } label: {
                    Label(LocalizedStringKey("remove_application"), systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "plus") // 菜单按钮图标
        }
    }

    /// 项目设置菜单，显示项目的默认应用程序并提供切换应用程序的选项。
    /// - Parameter item: 关联的 `ProjectModel` 实例。
    /// - Returns: 包含应用程序图标和操作菜单的视图。
    private func projectSetting(_ item: ProjectModel) -> some View {
        ZStack {
            Menu {
                Text(LocalizedStringKey("menu_current_application")) // 默认应用程序打开选项
                Button(action: {
                    item.open() // 使用默认应用程序打开项目
                }) {
                    Image(nsImage: item.applicationIcon)
                    Text(item.applicationName)
                }

                if dataManager.applications.count >= 2 {
                    Text(LocalizedStringKey("menu_available_applications")) // 其他可用应用程序
                    ForEach(dataManager.applications.filter { $0.path != item.applicationPath }, id: \.path) { app in
                        appButton(app) {
                            item.open(app.path) // 使用指定应用程序打开项目
                        }
                    }
                }
            } label: {
                Image(nsImage: item.applicationIcon) // 应用程序图标作为菜单触发器
            }
            .frame(width: 20, height: 20)
            .clipped()
            .cornerRadius(5)
            Image(nsImage: item.applicationIcon) // 显示应用程序图标
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .allowsHitTesting(false) // 禁用图标的点击交互
        }
    }

    /// 项目列表视图，显示过滤后的项目，支持点击打开和悬停高亮。
    private var projectsList: some View {
        List(dataManager.renderProjects, id: \.path) { item in
            HStack(spacing: 8) {
                projectSetting(item) // 项目设置菜单
                Text(item.name) // 项目名称
                    .foregroundStyle(item.exists ? Color.primary : Color.secondary)
                if !item.exists {
                    Image(systemName: "exclamationmark.triangle.fill") // 文件已被移动或删除
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help(Text(LocalizedStringKey("project_missing_title")))
                }
                Spacer(minLength: 4)
                // 用 Button 而不是 onTapGesture：避免与整行的打开手势竞争
                Button {
                    dataManager.removeProjects(item) // 删除项目
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(hoveredProject == item ? Color.secondary : Color.secondary.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
            .contentShape(Rectangle()) // 确保整行可点击
            .onHover { hovering in
                hoveredProject = hovering ? item : nil // 更新悬停状态
            }
            .onTapGesture {
                item.open() // 点击项目以默认应用程序打开
            }
            .listRowBackground(hoveredProject == item ? Color.accentColor.opacity(0.1) : Color.clear) // 悬停时高亮背景
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(QuickOpenerApp.sharedModelContainer)
        .environmentObject(QuickOpenerApp.dataManager)
}
