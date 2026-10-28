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

/// 主视图：E3 布局 —— 输入行 / 当前项横条 / 五列列表 / 快捷键底栏。
struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager
    @EnvironmentObject private var theme: ThemeManager

    /// 异步巡检结果（目录大小、Git 分支），就绪后自动刷新横条。
    @ObservedObject private var inspector = ProjectInspector.shared

    @State private var hoveredPath: String?
    @State private var settingsHovering = false
    @FocusState private var isFilterFocused: Bool
    /// 快捷键变化时自增，驱动 ⌥Z 徽标重绘。
    @State private var shortcutRevision = 0

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            inputRow
            tierBar
            listArea
            footBar
        }
        .frame(width: 780, height: 514)
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
        .onChange(of: dataManager.selectedProject?.path) { _, _ in
            // 选择变化时触发巡检（幂等，已算过的不会重复读盘）
            if let project = dataManager.selectedProject {
                inspector.inspect(project: project)
            }
        }
        .onAppear {
            if let project = dataManager.selectedProject {
                inspector.inspect(project: project)
            }
        }
    }

    // MARK: - 标题条

    /// 细标题条：整条作为窗口拖动区（SwiftUI 铺满内容后
    /// `isMovableByWindowBackground` 会失效，必须显式接管）。
    private var titleBar: some View {
        ZStack {
            WindowDragArea()

            HStack(spacing: 8) {
                Text(LocalizedStringKey("app_name"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(DS.text3)
                    .allowsHitTesting(false)

                Spacer(minLength: 0)
                    .allowsHitTesting(false)

                settingsButton

                Text(currentShortcut)
                    .font(DS.mono(11))
                    .foregroundStyle(DS.text3)
                    .padding(.horizontal, 6)
                    .frame(height: 20)
                    .background(DS.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .strokeBorder(DS.line, lineWidth: 1)
                    )
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 30)
    }

    /// 标题条右侧的偏好设置入口。
    ///
    /// 标题条整体是 `WindowDragArea`，这里靠 SwiftUI 的命中测试分层：
    /// 按钮在上层能收到点击，文字/Spacer 都设了 `allowsHitTesting(false)`，
    /// 空白处的事件仍会落到下层拖动区。
    private var settingsButton: some View {
        Button {
            (NSApp.delegate as? AppDelegate)?.showSetting()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(settingsHovering ? theme.accent : DS.text3)
                .frame(width: 22, height: 20)
                .background(settingsHovering ? DS.surface2 : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { settingsHovering = $0 }
        .help(Text(LocalizedStringKey("menu_settings")))
    }

    // MARK: - 输入行

    private var inputRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(theme.accent)

            TextField(
                "",
                text: $dataManager.filterText,
                prompt: Text(LocalizedStringKey("filter_projects")).foregroundColor(DS.text2)
            )
            .textFieldStyle(.plain)
            .font(.system(size: 18))
            .focused($isFilterFocused)

            Text(matchCountText)
                .font(DS.mono(11.5))
                .foregroundStyle(DS.text3)

            addProjectButton
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .overlay(alignment: .bottom) {
            Rectangle().fill(DS.line).frame(height: 1)
        }
    }

    /// 匹配数 / 总数，如 `2 / 24`。
    private var matchCountText: String {
        "\(dataManager.renderProjects.count) / \(dataManager.projects.count)"
    }

    /// 当前全局快捷键文案，未设置时回退到默认值。
    private var currentShortcut: String {
        _ = shortcutRevision
        return KeyboardShortcuts.getShortcut(for: .toggleProjectOpener)?.description ?? "⌥Z"
    }

    // MARK: - 当前项横条

    @ViewBuilder
    private var tierBar: some View {
        if let item = dataManager.selectedProject {
            VStack(spacing: 0) {
                HStack(spacing: 9) {
                    Image(nsImage: item.applicationIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 1)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(DS.textStrong)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Text((item.path as NSString).abbreviatingWithTildeInPath)
                            .font(DS.mono(12.5))
                            .foregroundStyle(DS.text3)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 8)

                    appChip(item)
                }
                .frame(height: 62)

                kpiRow(item)
                    .frame(height: 61)
            }
            .padding(.horizontal, 18)
            .background(DS.surface)
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [theme.accent.opacity(0.8), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 1)
            }
        }
    }

    /// 四枚指标：最近 / 次数 / 大小（异步）/ 分支（异步）。
    private func kpiRow(_ item: ProjectModel) -> some View {
        HStack(spacing: 0) {
            kpiCell(LocalizedStringKey("kpi_recent"), hot: true) {
                Text(relativeShort(item.lastOpenedAt))
                    .foregroundStyle(theme.accent)
            }
            kpiDivider
            kpiCell(LocalizedStringKey("kpi_count")) {
                Text(verbatim: "\(item.weight)")
                    .foregroundStyle(DS.text2)
            }
            kpiDivider
            kpiCell(LocalizedStringKey("kpi_size")) {
                if dataManager.missingPaths.contains(item.path) {
                    Text(verbatim: "—").foregroundStyle(DS.text3)
                } else if let stats = inspector.stats(for: item.path) {
                    Text(verbatim: ProjectInspector.format(bytes: stats.bytes))
                        .foregroundStyle(DS.text2)
                } else {
                    SkeletonBar(width: 30)
                }
            }
            kpiDivider
            kpiCell(LocalizedStringKey("kpi_branch")) {
                if dataManager.missingPaths.contains(item.path) {
                    Text(verbatim: "—").foregroundStyle(DS.text3)
                } else if let branch = inspector.branch(for: item.path) {
                    Text(verbatim: branch)
                        .foregroundStyle(DS.text2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else if inspector.branches[item.path] != nil {
                    // 已确认不是 Git 仓库
                    Text(verbatim: "—").foregroundStyle(DS.text3)
                } else {
                    SkeletonBar(width: 24)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func kpiCell<Content: View>(
        _ title: LocalizedStringKey,
        hot: Bool = false,
        @ViewBuilder value: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.15)
                .foregroundStyle(DS.text3)
                .lineLimit(1)
            value()
                .font(DS.mono(15))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var kpiDivider: some View {
        Rectangle()
            .fill(DS.line)
            .frame(width: 1, height: 30)
            .padding(.horizontal, 14)
    }

    /// 打开方式切换（点击弹出应用菜单）。
    private func appChip(_ item: ProjectModel) -> some View {
        Menu {
            Text(LocalizedStringKey("menu_current_application"))
            Button {
            } label: {
                Image(nsImage: item.applicationIcon)
                Text(item.applicationName)
            }
            .disabled(true) // 只作标记：用当前应用打开＝单击行，不在这里重复一次

            if dataManager.applications.count >= 2 {
                Text(LocalizedStringKey("menu_available_applications"))
                ForEach(dataManager.applications.filter { $0.path != item.applicationPath }, id: \.path) { app in
                    appButton(app) {
                        item.open(app.path)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(nsImage: item.applicationIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 13, height: 13)
                Text(item.applicationName)
                    .font(DS.mono(11))
            }
            .foregroundStyle(DS.text2)
            .padding(.horizontal, 10)
            .frame(height: 26)
            .background(DS.surface2)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(DS.line, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(height: 26)
        .help(Text(LocalizedStringKey("context_set_default_app")))
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
                        LazyVStack(spacing: 0) {
                            ForEach(Array(dataManager.renderProjects.enumerated()), id: \.element.path) { index, item in
                                projectRow(item, index: index)
                                    .id(item.path)
                            }
                        }
                        .padding(.horizontal, 18)
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

    /// 单行：序号 / 名称 / 父目录 / 时间 / ⌘N（悬停时换成垃圾桶）。
    private func projectRow(_ item: ProjectModel, index: Int) -> some View {
        let isSelected = dataManager.selectedProject?.path == item.path
        let isHovered = hoveredPath == item.path
        let isMissing = dataManager.missingPaths.contains(item.path)

        return HStack(spacing: 8) {
            Text(String(format: "%02d", index + 1))
                .font(DS.mono(11))
                .foregroundStyle(isSelected ? theme.accent : DS.text3)
                .frame(width: 26, alignment: .leading)

            highlightedName(item.name, selected: isSelected, missing: isMissing)
                .font(.system(size: 14))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(isMissing ? NSLocalizedString("project_missing_title", comment: "") : parentPath(item.path))
                .font(DS.mono(11.5))
                .foregroundStyle(isMissing ? DS.warn : (isSelected ? theme.accent : DS.text3))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 180, alignment: .trailing)

            Text(relativeShort(item.lastOpenedAt))
                .font(DS.mono(11.5))
                .foregroundStyle(isSelected ? theme.accent : DS.text3)
                .frame(width: 52, alignment: .trailing)

            Group {
                if isHovered {
                    Button {
                        dataManager.removeProjects(item)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(DS.text2)
                    }
                    .buttonStyle(.plain)
                } else if isSelected, index < 9 {
                    Text("⌘\(index + 1)")
                        .font(DS.mono(10))
                        .foregroundStyle(theme.accent.opacity(0.85))
                } else if isMissing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(DS.warn)
                }
            }
            .frame(width: 42, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(rowFill(selected: isSelected, hovered: isHovered))
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
            // ── 打开 ──
            Button {
                item.open()
            } label: {
                Label(LocalizedStringKey("context_open"), systemImage: "arrow.up.forward.app")
            }

            Divider()

            // ── 定位 ──
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Label(LocalizedStringKey("context_reveal_in_finder"), systemImage: "folder")
            }

            if let terminal = terminalAppURL {
                Button {
                    openWith(terminal, project: item)
                } label: {
                    Label(LocalizedStringKey("context_open_in_terminal"), systemImage: "terminal")
                }
            }

            if let code = vsCodeAppURL {
                Button {
                    openWith(code, project: item)
                } label: {
                    Label(LocalizedStringKey("context_open_in_code"), systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            Divider()

            // ── 复制 ──
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.path, forType: .string)
            } label: {
                Label(LocalizedStringKey("context_copy_path"), systemImage: "doc.on.doc")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.name, forType: .string)
            } label: {
                Label(LocalizedStringKey("context_copy_name"), systemImage: "textformat")
            }

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.writeObjects([item.url as NSURL])
            } label: {
                Label(LocalizedStringKey("context_copy_file"), systemImage: "doc.on.clipboard")
            }

            Divider()

            // ── 维护 ──
            Picker(LocalizedStringKey("context_set_default_app"), selection: Binding(
                get: { item.applicationPath },
                set: { dataManager.setApplicationPath($0, for: item) }
            )) {
                ForEach(dataManager.applications, id: \.path) { app in
                    Text(app.name).tag(app.path)
                }
            }

            Button {
                inspector.forget(path: item.path)
                inspector.inspect(project: item)
            } label: {
                Label(LocalizedStringKey("context_recalculate"), systemImage: "arrow.clockwise")
            }

            Divider()

            Button(role: .destructive) {
                dataManager.removeProjects(item)
            } label: {
                Label(LocalizedStringKey("context_remove_from_list"), systemImage: "trash")
            }
        }
    }

    /// 名称在搜索命中处染色。
    private func highlightedName(_ name: String, selected: Bool, missing: Bool) -> Text {
        let query = dataManager.filterText
        let baseColor: Color = selected ? DS.textStrong : (missing ? DS.text3 : DS.text)

        guard !query.isEmpty,
              let range = name.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return Text(name).foregroundColor(baseColor)
        }

        let before = String(name[name.startIndex..<range.lowerBound])
        let match = String(name[range])
        let after = String(name[range.upperBound...])

        return Text(before).foregroundColor(baseColor)
            + Text(match).foregroundColor(theme.accent).bold()
            + Text(after).foregroundColor(baseColor)
    }

    @ViewBuilder
    private func rowFill(selected: Bool, hovered: Bool) -> some View {
        if selected {
            LinearGradient(
                colors: [theme.accent.opacity(0.15), theme.accent.opacity(0.015)],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else if hovered {
            theme.accent.opacity(0.07)
        } else {
            Color.clear
        }
    }

    // MARK: - 空态

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(DS.text3)
            Text(LocalizedStringKey("empty_state_title"))
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(DS.text)
            Text(LocalizedStringKey("empty_state_hint"))
                .font(.system(size: 14))
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
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DS.text3)
            Text(LocalizedStringKey("no_match_hint"))
                .font(.system(size: 14))
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
            Text(matchCountText)
                .font(DS.mono(11))
                .foregroundStyle(DS.text3)
        }
        .padding(.horizontal, 16)
        .frame(height: 38)
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
        .font(DS.mono(11))
        .foregroundStyle(DS.text3)
    }

    // MARK: - 菜单

    /// 添加项目 / 管理应用的菜单按钮。
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
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(DS.text2)
                .frame(width: 30, height: 28)
                .background(DS.surface2)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .strokeBorder(DS.line, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 30, height: 28)
        .help(Text(LocalizedStringKey("add_projects")))
    }

    /// 用指定应用打开项目（「用其他应用打开 / 终端 / VS Code」共用）。
    ///
    /// 成功后与 `ProjectModel.open()` 一致地收起窗口；失败保留窗口让用户重试。
    private func openWith(_ appURL: URL, project: ProjectModel) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true

        // 与 ProjectModel.open() 一致：沙盒下交给别的应用前先开安全作用域
        let scopedURL = project.bookmarkURL
        let urlToUse = scopedURL ?? project.url
        let accessGranted = scopedURL?.startAccessingSecurityScopedResource() ?? false

        NSWorkspace.shared.open([urlToUse], withApplicationAt: appURL, configuration: configuration) { _, error in
            if accessGranted, let scopedURL {
                scopedURL.stopAccessingSecurityScopedResource()
            }
            guard error == nil else { return }
            Task { @MainActor in
                QuickOpenerApp.dataManager.hideHostingWindow()
            }
        }
    }

    /// 系统「终端」的位置；找不到就不显示该菜单项。
    private var terminalAppURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
    }

    /// VS Code 的位置；未安装就不显示该菜单项。
    private var vsCodeAppURL: URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.microsoft.VSCode")
    }

    private func appButton(_ app: ApplicationModel, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(nsImage: app.icon)
            Text(app.name)
        }
    }

    // MARK: - 格式化

    /// 父目录，`~` 缩写。
    private func parentPath(_ path: String) -> String {
        ((path as NSString).deletingLastPathComponent as NSString).abbreviatingWithTildeInPath
    }

    /// 紧凑相对时间：2h / 3d / 2w / 1mo。
    private func relativeShort(_ date: Date?) -> String {
        guard let date else { return "—" }
        let delta = -date.timeIntervalSinceNow
        guard delta > 0 else { return "0m" }
        if delta < 3600 { return "\(max(1, Int(delta / 60)))m" }
        if delta < 86_400 { return "\(Int(delta / 3600))h" }
        if delta < 604_800 { return "\(Int(delta / 86_400))d" }
        if delta < 2_592_000 { return "\(Int(delta / 604_800))w" }
        return "\(Int(delta / 2_592_000))mo"
    }
}

#Preview {
    ContentView()
        .modelContainer(QuickOpenerApp.sharedModelContainer)
        .environmentObject(QuickOpenerApp.dataManager)
        .environmentObject(ThemeManager.shared)
        .preferredColorScheme(.dark)
}
