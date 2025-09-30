//
//  ContentView.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

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
    }

    /// 头部控件，包含过滤文本输入框和添加项目按钮。
    private var headerControls: some View {
        HStack {
            TextField(LocalizedStringKey("filter_projects"), text: $dataManager.filterText) // 输入框，用于过滤项目列表
            addProjectButton // 添加项目和应用程序的菜单按钮
        }
    }

    /// 创建应用程序选择按钮，显示应用程序图标和名称。
    /// - Parameters:
    ///   - app: 要显示的 `ApplicationModel` 实例。
    ///   - action: 按钮点击时的操作。
    /// - Returns: 包含图标和名称的按钮视图，鼠标悬停时更新光标。
    private func appButton(_ app: ApplicationModel, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(nsImage: app.icon)
            Text(app.name)
        }
        .onHover(perform: updateCursor)
    }

    /// 添加项目和应用程序的菜单按钮，主操作触发添加项目，菜单提供应用程序选择和添加功能。
    private var addProjectButton: some View {
        Menu {
            Text(LocalizedStringKey("menu_current_application")) // 显示当前应用程序
            appButton(dataManager.currentApplication) {
                // 无需执行，显示默认应用
            }

            if dataManager.applications.count >= 2 {
                Text(LocalizedStringKey("menu_available_applications")) // 列出其他可用应用程序
                ForEach(dataManager.applications.filter { $0.path != dataManager.currentApplication.path }, id: \.id) { app in
                    appButton(app) {
                        dataManager.selectApplication(app) // 选择其他应用程序
                    }
                }
            }

            Text(LocalizedStringKey("menu_actions")) // 其他操作选项
            Button(action: {
                dataManager.addApplication() // 打开面板添加新应用程序
            }) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Applications/App Store.app"))
                Text(LocalizedStringKey("add_application"))
            }
            .onHover(perform: updateCursor)
        } label: {
            Image(systemName: "plus") // 菜单按钮图标
        } primaryAction: {
            dataManager.addProjects() // 主操作：添加项目
        }
        .id(dataManager.currentApplication.id) // 确保菜单随当前应用程序更新
        .onHover(perform: updateCursor) // 鼠标悬停时更新光标
    }

    /// 项目设置菜单，显示项目的默认应用程序并提供切换应用程序或删除项目的选项。
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
                .onHover(perform: updateCursor)

                if dataManager.applications.count >= 2 {
                    Text(LocalizedStringKey("menu_available_applications")) // 其他可用应用程序
                    ForEach(dataManager.applications.filter { $0.path != item.applicationPath }, id: \.self) { app in
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
        List(dataManager.renderProjects, id: \.self) { item in
            HStack {
                projectSetting(item) // 项目设置菜单
                Text(item.name) // 项目名称
                Spacer()
                Image(systemName: "trash")
                    .onTapGesture {
                        dataManager.removeProjects(item) // 删除项目
                    }
            }
            .contentShape(Rectangle()) // 确保整行可点击
            .onHover { hovering in
                hoveredProject = hovering ? item : nil // 更新悬停状态
                updateCursor(isHovering: hovering) // 更新光标
            }
            .onTapGesture {
                item.open() // 点击项目以默认应用程序打开
            }
            .listRowBackground(hoveredProject == item ? Color.blue.opacity(0.1) : Color.clear) // 悬停时高亮背景
        }
    }

    /// 更新鼠标光标样式，悬停时显示手形光标，离开时恢复箭头光标。
    /// - Parameter isHovering: 是否处于悬停状态。
    private func updateCursor(isHovering: Bool) {
        if isHovering {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(QuickOpenerApp.sharedModelContainer)
        .environmentObject(QuickOpenerApp.dataManager)
}
