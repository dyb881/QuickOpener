//
//  ContentView.swift
//  ProjectOpener
//
//  Created by 邓耀彬 on 2025/9/26.
//

import AppKit
import KeyboardShortcuts
import SwiftData
import SwiftUI

/// 主视图：搜索、项目列表与快捷键底栏（深色玻璃视觉）。
struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var theme: ThemeManager

    @State private var hoveredPath: String?
    @FocusState private var isFilterFocused: Bool
    /// 快捷键变化时自增，驱动标题栏徽标重绘。
    @State private var shortcutRevision = 0

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            searchRow
            listArea
            footBar
        }
        .frame(width: 300, height: 500)
        .background(
            ZStack {
                VisualEffectBackground()
                DS.windowGradient.opacity(0.97)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.radius, style: .continuous))
        .overlay(GlassBorder())
        .tint(theme.accent)
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
            isFilterFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("KeyboardShortcuts_shortcutByNameDidChange"))) { _ in
            shortcutRevision += 1
        }
        .onChange(of: dataManager.filterText) { _, _ in
            dataManager.selectedIndex = 0
        }
    }

    // MARK: - 标题栏

    /// 自绘标题栏：左侧让出窗口红绿灯位置，右侧显示当前唤起快捷键。
    private var titleBar: some View {
        ZStack {
            WindowDragArea() // 整条标题栏都能拖动窗口

            HStack(spacing: 0) {
                Spacer(minLength: 0)
                Text(currentShortcut)
                    .font(DS.mono(10))
                    .foregroundStyle(DS.text3)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(DS.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(DS.line, lineWidth: 1)
                    )
            }
            .padding(.trailing, 10)
            .allowsHitTesting(false) // 让拖动区拿到鼠标事件
        }
        .frame(height: 38)
    }

    /// 当前全局快捷键文案，未设置时回退到默认值。
    private var currentShortcut: String {
        _ = shortcutRevision
        return KeyboardShortcuts.getShortcut(for: .toggleProjectOpener)?.description ?? "⌥Z"
    }

    // MARK: - 搜索

    private var searchRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.accent)
                TextField(
                    "",
                    text: $dataManager.filterText,
                    prompt: Text(LocalizedStringKey("filter_projects")).foregroundColor(DS.text2)
                )
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .focused($isFilterFocused)
            }
            .padding(.horizontal, 9)
            .frame(height: 28)
            .background(theme.accent.opacity(0.045))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.34), lineWidth: 1)
            )

            addProjectButton
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }

    // MARK: - 列表

    private var listArea: some View {
        Group {
            if dataManager.renderProjects.isEmpty {
                if dataManager.projects.isEmpty {
                    emptyState
                } else {
                    noMatchState
                }
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(dataManager.renderProjects.enumerated()), id: \.element.path) { index, item in
                                projectRow(item, index: index)
                                    .id(item.path)
                            }
                        }
                        .padding(6)
                    }
                    .scrollIndicators(.automatic)
                    .onChange(of: dataManager.selectedProject?.path) { _, newPath in
                        guard let newPath else { return }
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(newPath)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(DS.text3)
            Text(LocalizedStringKey("empty_state_title"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DS.text)
            Text(LocalizedStringKey("empty_state_hint"))
                .font(.system(size: 11))
                .foregroundStyle(DS.text3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                dataManager.addProjects()
            } label: {
                Label(LocalizedStringKey("add_projects"), systemImage: "plus")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }

    private var noMatchState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(DS.text3)
            Text(LocalizedStringKey("no_match_hint"))
                .font(.system(size: 11))
                .foregroundStyle(DS.text3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底栏

    private var footBar: some View {
        HStack(spacing: 12) {
            footItem("↑↓", key: "foot_select")
            footItem("↩", key: "foot_open")
            footItem("esc", key: "foot_close")
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 30)
        .background(DS.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(DS.line).frame(height: 1)
        }
    }

    private func footItem(_ symbol: String, key: String) -> some View {
        HStack(spacing: 4) {
            Text(symbol).foregroundStyle(DS.text2)
            Text(LocalizedStringKey(key))
        }
        .font(DS.mono(9.5))
        .foregroundStyle(DS.text3)
    }

    // MARK: - 单行

    /// 单行项目：应用图标菜单 + 名称 + 父目录 + 快捷键徽标 / 删除按钮。
    private func projectRow(_ item: ProjectModel, index: Int) -> some View {
        let isSelected = dataManager.selectedProject?.path == item.path
        let isHovered = hoveredPath == item.path
        let isMissing = dataManager.missingPaths.contains(item.path)

        return HStack(spacing: 10) {
            projectSetting(item)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? DS.textStrong : (isMissing ? DS.text3 : DS.text))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(isMissing
                     ? NSLocalizedString("project_missing_title", comment: "")
                     : parentPath(item.path))
                    .font(DS.mono(9.5))
                    .foregroundStyle(isMissing ? DS.warn : DS.text3)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)

            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(DS.warn)
                    .help(Text(LocalizedStringKey("project_missing_title")))
            }

            if isHovered {
                Button {
                    dataManager.removeProjects(item)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(DS.text2)
                }
                .buttonStyle(.plain)
            } else if isSelected, index < 9 {
                KeyCap(text: "⌘\(index + 1)", tint: theme.accent)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 38)
        .background(rowFill(selected: isSelected, hovered: isHovered))
        .clipShape(RoundedRectangle(cornerRadius: DS.rowRadius, style: .continuous))
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(theme.accent)
                    .frame(width: 2, height: 20)
                    .padding(.leading, 1)
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: DS.rowRadius, style: .continuous)
                    .strokeBorder(theme.accent.opacity(0.22), lineWidth: 1)
            }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredPath = hovering ? item.path : nil
            if hovering {
                dataManager.selectedIndex = index
            }
        }
        .onTapGesture {
            item.open()
        }
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
    @ViewBuilder
    private func rowFill(selected: Bool, hovered: Bool) -> some View {
        if selected {
            LinearGradient(
                colors: [theme.accent.opacity(0.16), theme.accent.opacity(0.015)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if hovered {
            theme.accent.opacity(0.07)
        } else {
            Color.clear
        }
    }

    /// 行内第二行显示的父目录，`~` 缩写。
    private func parentPath(_ path: String) -> String {
        ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
    }

    // MARK: - 菜单

    private func appButton(_ app: ApplicationModel, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(nsImage: app.icon)
            Text(app.name)
        }
    }

    /// 添加项目 / 管理应用的菜单按钮（不用 primaryAction，否则菜单难以展开）。
    private var addProjectButton: some View {
        Menu {
            Button {
                dataManager.addProjects()
            } label: {
                Label(LocalizedStringKey("add_projects"), systemImage: "plus.square.on.square")
            }

            Divider()

            Text(LocalizedStringKey("menu_current_application"))
            Button {
            } label: {
                Image(nsImage: dataManager.currentApplication.icon)
                Text(dataManager.currentApplication.name)
            }
            .disabled(true)

            if dataManager.applications.count >= 2 {
                Text(LocalizedStringKey("menu_available_applications"))
                ForEach(dataManager.applications.filter { $0.path != dataManager.currentApplication.path }, id: \.path) { app in
                    appButton(app) {
                        dataManager.selectApplication(app)
                    }
                }
            }

            Divider()

            Button {
                dataManager.addApplication()
            } label: {
                Label(LocalizedStringKey("add_application"), systemImage: "app.badge.plus")
            }

            if dataManager.applications.contains(where: { $0.path != ApplicationModel.defaultApplicationPath }) {
                Menu {
                    ForEach(dataManager.applications.filter { $0.path != ApplicationModel.defaultApplicationPath }, id: \.path) { app in
                        Button(role: .destructive) {
                            dataManager.removeApplication(app)
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
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DS.text2)
                .frame(width: 28, height: 28)
                .background(DS.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(DS.line, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28, height: 28)
        .help(Text(LocalizedStringKey("add_projects")))
    }

    /// 项目设置菜单：点击行首应用图标切换打开方式。
    private func projectSetting(_ item: ProjectModel) -> some View {
        ZStack {
            Menu {
                Text(LocalizedStringKey("menu_current_application"))
                Button(action: {
                    item.open()
                }) {
                    Image(nsImage: item.applicationIcon)
                    Text(item.applicationName)
                }

                if dataManager.applications.count >= 2 {
                    Text(LocalizedStringKey("menu_available_applications"))
                    ForEach(dataManager.applications.filter { $0.path != item.applicationPath }, id: \.path) { app in
                        appButton(app) {
                            item.open(app.path)
                        }
                    }
                }
            } label: {
                Image(nsImage: item.applicationIcon)
            }
            .frame(width: 22, height: 22)
            .clipped()
            .cornerRadius(DS.iconRadius)
            Image(nsImage: item.applicationIcon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .allowsHitTesting(false)
        }
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: DS.iconRadius, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }
}

#Preview {
    ContentView()
        .modelContainer(QuickOpenerApp.sharedModelContainer)
        .environmentObject(QuickOpenerApp.dataManager)
        .environmentObject(ThemeManager.shared)
        .preferredColorScheme(.dark)
}
