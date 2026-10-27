//
//  ContentView.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import Combine
import SwiftData
import SwiftUI
internal import UniformTypeIdentifiers

/// 主视图，显示项目列表和应用程序选择控件，用于管理文件和打开方式。
struct ContentView: View {
    /// 环境对象，引用 `DataManager` 来管理项目和应用程序数据。
    @EnvironmentObject private var dataManager: DataManager

    /// 状态变量，跟踪当前鼠标悬停的项目路径。
    @State private var hoveredPath: String?

    /// 搜索框焦点：窗口每次显示时自动聚焦，省掉「先用鼠标点输入框」这一步。
    @FocusState private var isFilterFocused: Bool

    /// 是否有文件正被拖到窗口上（用于显示接收高亮）。
    @State private var isDropTargeted = false

    /// 视图主体，包含头部控件和项目列表，设置固定窗口大小。
    var body: some View {
        VStack {
            headerControls
                .padding([.horizontal, .top])
            projectsList(selectedPath: dataManager.selectedProject?.path)
        }
        .frame(width: 300, height: 500)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.accentColor, lineWidth: isDropTargeted ? 2 : 0)
                .allowsHitTesting(false) // 不能挡住拖放命中
        )
        .overlay(alignment: .bottom) {
            if let notice = dataManager.notice {
                Text(notice)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: dataManager.notice)
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
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
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            // 窗口每次获得焦点（首次显示或被复用后重新显示）都把光标放进搜索框
            isFilterFocused = true
        }
        .onChange(of: dataManager.filterText) { _, _ in
            dataManager.selectedIndex = 0 // 过滤结果变了，选中项回到第一行
        }
    }

    /// 接收从 Finder 拖入的文件/文件夹，异步解析成 URL 后加入列表。
    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else { return false }

        let group = DispatchGroup()
        let lock = NSLock()
        var urls: [URL] = []

        for provider in fileProviders {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                defer { group.leave() }
                let resolved: URL?
                if let data = item as? Data {
                    resolved = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    resolved = item as? URL
                }
                guard let url = resolved else { return }
                lock.lock()
                urls.append(url)
                lock.unlock()
            }
        }

        group.notify(queue: .main) {
            guard !urls.isEmpty else { return }
            dataManager.addDroppedItems(urls)
        }
        return true
    }

    /// 头部控件，包含过滤文本输入框和添加项目按钮。
    private var headerControls: some View {
        HStack {
            TextField(LocalizedStringKey("filter_projects"), text: $dataManager.filterText) // 输入框，用于过滤项目列表
                .focused($isFilterFocused)
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

    /// 项目列表视图，显示过滤后的项目，支持点击打开、悬停与键盘选中高亮。
    private func projectsList(selectedPath: String?) -> some View {
        ScrollViewReader { proxy in
            List(dataManager.renderProjects, id: \.path) { item in
                projectRow(item, selectedPath: selectedPath)
                    .id(item.path)
            }
            .onChange(of: selectedPath) { _, newPath in
                guard let newPath = newPath else { return }
                // anchor 为 nil：已可见时不滚动，只有超出可视区域才跟随
                withAnimation(.easeInOut(duration: 0.1)) {
                    proxy.scrollTo(newPath)
                }
            }
        }
    }

    /// 单行项目视图。
    private func projectRow(_ item: ProjectModel, selectedPath: String?) -> some View {
        HStack(spacing: 8) {
            projectSetting(item) // 项目设置菜单
            Text(item.name) // 项目名称
                .foregroundStyle(dataManager.missingPaths.contains(item.path) ? Color.secondary : Color.primary)
            if dataManager.missingPaths.contains(item.path) {
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
                    .foregroundStyle(hoveredPath == item.path ? Color.secondary : Color.secondary.opacity(0.45))
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle()) // 确保整行可点击
        .onHover { hovering in
            hoveredPath = hovering ? item.path : nil // 更新悬停状态
            if hovering, let index = dataManager.renderProjects.firstIndex(where: { $0.path == item.path }) {
                dataManager.selectedIndex = index // 鼠标悬停与键盘选中保持一致
            }
        }
        .onTapGesture {
            item.open() // 点击项目以默认应用程序打开
        }
        .listRowBackground(rowBackground(for: item, selectedPath: selectedPath))
        .contextMenu {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label(LocalizedStringKey("context_reveal_in_finder"), systemImage: "folder")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path, forType: .string)
            } label: {
                Label(LocalizedStringKey("context_copy_path"), systemImage: "doc.on.doc")
            }

            Divider()

            // 子菜单里直接改这个项目的默认打开应用
            Picker(LocalizedStringKey("context_set_default_app"), selection: Binding(
                get: { item.applicationPath },
                set: { dataManager.setApplicationPath($0, for: item) }
            )) {
                ForEach(dataManager.applications, id: \.path) { app in
                    Text(app.name).tag(app.path)
                }
            }

            Divider()

            Button(role: .destructive) {
                dataManager.removeProjects(item)
            } label: {
                Label(LocalizedStringKey("context_remove_from_list"), systemImage: "trash")
            }
        }
    }

    /// 行背景：键盘选中 > 鼠标悬停 > 透明。
    private func rowBackground(for item: ProjectModel, selectedPath: String?) -> Color {
        if selectedPath == item.path {
            return Color.accentColor.opacity(0.18)
        }
        if hoveredPath == item.path {
            return Color.accentColor.opacity(0.08)
        }
        return Color.clear
    }
}

#Preview {
    ContentView()
        .modelContainer(QuickOpenerApp.sharedModelContainer)
        .environmentObject(QuickOpenerApp.dataManager)
}
