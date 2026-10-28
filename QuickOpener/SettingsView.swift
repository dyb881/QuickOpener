//
//  SettingsView.swift
//  ProjectOpener
//
//  Created by 邓耀彬 on 2025/9/26.
//

import AppKit
import KeyboardShortcuts
import ServiceManagement
import SwiftData
import SwiftUI
internal import UniformTypeIdentifiers

struct SettingsView: View {
    // "" 代表系统默认
    @AppStorage("appLanguage") private var appLanguage: String = ""

    /// 主题强调色，选择后立即生效并持久化。
    @EnvironmentObject private var theme: ThemeManager

    /// 数据管理，用于导入导出项目列表。
    @EnvironmentObject private var dataManager: DataManager

    /// 自动重启失败时提示用户，避免点了按钮后应用直接退出。
    @State private var restartFailed = false

    /// 登录项开关状态（初值取当前系统状态）。
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    /// 登录项设置失败提示。
    @State private var launchAtLoginFailed = false

    /// 导入结果摘要，非空时弹提示。
    @State private var importSummary: String?
    @State private var showClearCacheAlert = false
    @State private var selectedTab: SettingsTab = .general

    // 支持的语言选项
    private let languages = [
        ("system_default", ""),
        ("english", "en"),
        ("chinese_simplified", "zh-Hans"),
        ("chinese_traditional", "zh-Hant"),
        ("japanese", "ja"),
        ("korean", "ko"),
        ("german", "de"),
        ("french", "fr"),
        ("spanish", "es"),
    ]

    /// 主题色色块：选中项外圈加粗并打勾，悬停显示色名。
    @ViewBuilder
    private func themeSwatch(_ item: AccentTheme) -> some View {
        let isSelected = theme.theme == item
        Button {
            theme.theme = item
        } label: {
            ZStack {
                if let preset = item.presetColor {
                    Circle().fill(preset)
                } else {
                    // 跟随系统：多色环表示「自动」
                    Circle()
                        .fill(AngularGradient(
                            colors: [.red, .orange, .yellow, .green, .blue, .purple, .red],
                            center: .center
                        ))
                        .opacity(0.9)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 0.5)
                }
            }
            .frame(width: 22, height: 22)
            .overlay(Circle().strokeBorder(Color.primary.opacity(0.18), lineWidth: 1))
            .overlay(
                Circle()
                    .strokeBorder(Color.primary, lineWidth: 1.5)
                    .scaleEffect(1.28)
                    .opacity(isSelected ? 1 : 0)
            )
            .padding(3)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(Text(LocalizedStringKey(item.localizedKey)))
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            contentPane
        }
        .frame(width: 760)
        .frame(minHeight: 300, maxHeight: .infinity) // 高度跟随窗口（含标题栏区域），背景才能铺满
        // 设置窗口不透明（系统标题栏需要稳定背景），所以这里铺不透明渐变。
        // 材质与透明度只作用于主窗口。
        .background(DS.windowGradient)
        .tint(theme.accent)
        .alert(LocalizedStringKey("restart_failed_title"), isPresented: $restartFailed) {
            Button(role: .cancel) {} label: { Text(verbatim: "OK") }
        } message: {
            Text(LocalizedStringKey("restart_failed_message"))
        }
        .alert(LocalizedStringKey("launch_at_login_failed_title"), isPresented: $launchAtLoginFailed) {
            Button(role: .cancel) {} label: { Text(verbatim: "OK") }
        } message: {
            Text(LocalizedStringKey("launch_at_login_failed_message"))
        }
        .alert(
            LocalizedStringKey("import_result_title"),
            isPresented: Binding(
                get: { importSummary != nil },
                set: { if !$0 { importSummary = nil } }
            ),
            presenting: importSummary
        ) { _ in
            Button(role: .cancel) {} label: { Text(verbatim: "OK") }
        } message: { summary in
            Text(verbatim: summary)
        }
        .alert(LocalizedStringKey("reset_cache_confirm_title"), isPresented: $showClearCacheAlert) {
            Button(LocalizedStringKey("button_cancel"), role: .cancel) {}
            Button(LocalizedStringKey("button_clear"), role: .destructive) {
                dataManager.clearCache()
            }
        } message: {
            Text(LocalizedStringKey("reset_cache_confirm_message"))
        }
    }


    // MARK: - 侧边栏

    /// 设置页签。侧边栏与内容区共用同一份枚举，避免两处顺序不一致。
    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general, appearance, language, shortcuts, data, about

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .general:   return "settings_general"
            case .appearance: return "settings_appearance"
            case .language:  return "settings_language"
            case .shortcuts: return "settings_shortcuts"
            case .data:      return "settings_data"
            case .about:     return "settings_about"
            }
        }

        var systemImage: String {
            switch self {
            case .general:   return "gearshape"
            case .appearance: return "paintpalette"
            case .language:  return "globe"
            case .shortcuts: return "command"
            case .data:      return "externaldrive"
            case .about:     return "info.circle"
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(SettingsTab.allCases) { tab in
                sidebarRow(tab)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .frame(width: 172)
        .frame(maxHeight: .infinity)
        .background(DS.surface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DS.line)
                .frame(width: 1)
        }
    }

    private func sidebarRow(_ tab: SettingsTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 9) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(LocalizedStringKey(tab.titleKey))
                    .font(.system(size: 12.5))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? DS.textStrong : DS.text2)
            .padding(.horizontal, 9)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? theme.accent.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 内容区

    private var contentPane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                switch selectedTab {
                case .general:    generalPane
                case .appearance: appearancePane
                case .language:   languagePane
                case .shortcuts:  shortcutsPane
                case .data:       dataPane
                case .about:      aboutPane
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 各页内容

    private var generalPane: some View {
        section("settings_general") {
            card {
                HStack {
                    Text(LocalizedStringKey("settings_launch_at_login"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(DS.text)
                    Spacer(minLength: 12)
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .tint(theme.accent)
                        .onChange(of: launchAtLogin) { _, enabled in
                            updateLaunchAtLogin(enabled)
                        }
                }
            }
        }
    }

    private var appearancePane: some View {
        section("settings_appearance") {
            card {
                VStack(spacing: 10) {
                    HStack {
                        Text(LocalizedStringKey("appearance_mode"))
                            .font(.system(size: 12.5))
                            .foregroundStyle(DS.text)
                        Spacer(minLength: 12)
                        Picker("", selection: $theme.appearance) {
                            ForEach(AppearanceMode.allCases) { mode in
                                Text(LocalizedStringKey(mode.localizedKey)).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 216)
                    }

                    Rectangle().fill(DS.line).frame(height: 1)

                    HStack {
                        Text(LocalizedStringKey("theme_color"))
                            .font(.system(size: 12.5))
                            .foregroundStyle(DS.text)
                        Spacer(minLength: 12)
                        HStack(spacing: 10) {
                            ForEach(AccentTheme.allCases) { item in
                                themeSwatch(item)
                            }
                        }
                    }

                    Rectangle().fill(DS.line).frame(height: 1)

                    HStack {
                        Text(LocalizedStringKey("label_backdrop"))
                            .font(.system(size: 12.5))
                            .foregroundStyle(DS.text)
                        Spacer(minLength: 12)
                        Picker("", selection: $theme.backdrop) {
                            ForEach(WindowBackdrop.allCases) { item in
                                Text(LocalizedStringKey(item.localizedKey)).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 216)
                    }

                    Rectangle().fill(DS.line).frame(height: 1)

                    HStack(spacing: 10) {
                        Text(LocalizedStringKey("label_opacity"))
                            .font(.system(size: 12.5))
                            .foregroundStyle(DS.text)
                        Spacer(minLength: 8)
                        Slider(value: $theme.windowOpacity, in: 0.35...1.0)
                            .controlSize(.small)
                            .tint(theme.accent)
                            .frame(width: 176)
                        Text(verbatim: "\(Int((theme.windowOpacity * 100).rounded()))%")
                            .font(DS.mono(11))
                            .foregroundStyle(DS.text3)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var languagePane: some View {
        section("settings_language") {
            card {
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(LocalizedStringKey("label_language"))
                            .font(.system(size: 12.5))
                            .foregroundStyle(DS.text)
                        Spacer(minLength: 12)
                        Picker("", selection: $appLanguage) {
                            ForEach(languages, id: \.1) { name, code in
                                Text(LocalizedStringKey(name)).tag(code)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 216)
                        .onChange(of: appLanguage) { _, language in
                            // AppleLanguages UserDefaults 是设置每应用语言的唯一方案
                            UserDefaults.standard.set(language.isEmpty ? nil : [language], forKey: "AppleLanguages")
                        }
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                        Text(LocalizedStringKey("restart_takes_effect"))
                            .font(.system(size: 10.5))
                        Spacer(minLength: 8)
                        Button(LocalizedStringKey("button_restart")) {
                            restartApp()
                        }
                        .controlSize(.small)
                    }
                    .frame(maxWidth: .infinity) // VStack(alignment: .leading) 里不撑满，Spacer 会失效
                    .foregroundStyle(DS.text3)
                }
            }
        }
    }

    private var shortcutsPane: some View {
        section("settings_shortcuts") {
            card {
                HStack {
                    Text(LocalizedStringKey("label_shortcut"))
                        .font(.system(size: 12.5))
                        .foregroundStyle(DS.text)
                    Spacer(minLength: 12)
                    KeyboardShortcuts.Recorder(for: .toggleProjectOpener)
                    Button(LocalizedStringKey("button_reset_shortcut")) {
                        KeyboardShortcuts.reset(.toggleProjectOpener)
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private var dataPane: some View {
        section("settings_data") {
            card {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(spacing: 8) {
                        Button(LocalizedStringKey("button_export_projects")) {
                            exportProjects()
                        }
                        .controlSize(.small)
                        Button(LocalizedStringKey("button_import_projects")) {
                            importProjects()
                        }
                        .controlSize(.small)
                        Spacer(minLength: 0)
                    }

                    Rectangle().fill(DS.line).frame(height: 1)

                    HStack(spacing: 8) {
                        Button(LocalizedStringKey("menu_reset_cache")) {
                            showClearCacheAlert = true
                        }
                        .controlSize(.small)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }

    private var aboutPane: some View {
        section("settings_about") {
            card {
                HStack(spacing: 13) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(DS.iconPlate)
                        Image(systemName: "rectangle.on.rectangle.angled")
                            .font(.system(size: 19, weight: .light))
                            .foregroundStyle(theme.accent)
                    }
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(DS.line2, lineWidth: 1)
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(verbatim: "QuickOpener \(appVersion)")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(DS.text)
                        Text(LocalizedStringKey("app_description_short"))
                            .font(.system(size: 10.5))
                            .foregroundStyle(DS.text3)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - 布局组件

    /// 分区标题：小号大写 + 一条渐隐分隔线。
    private func section<Content: View>(_ titleKey: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Text(LocalizedStringKey(titleKey))
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.9)
                    .foregroundStyle(DS.text3)
                Rectangle()
                    .fill(DS.line)
                    .frame(height: 1)
            }
            content()
        }
    }

    /// 卡片容器：淡色底 + 1px 描边 + 圆角。
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.surface)
            .clipShape(RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.cardRadius, style: .continuous)
                    .strokeBorder(DS.line, lineWidth: 1)
            )
    }

    /// 版本号从 Bundle 读取，避免硬编码与工程配置不同步。
    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(v) (\(b))"
    }

    /// 读写系统登录项。失败时回滚开关状态并提示。
    private func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("登录项设置失败: \(error.localizedDescription)")
            launchAtLoginFailed = true
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    /// 导出项目列表为 JSON 文件。
    private func exportProjects() {
        guard let data = dataManager.exportPayload() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "QuickOpener-Projects.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("导出失败: \(error.localizedDescription)")
        }
    }

    /// 从 JSON 文件导入项目列表（按路径去重）。
    private func importProjects() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let data = try? Data(contentsOf: url),
              let result = dataManager.importPayload(from: data) else {
            print("导入失败：文件格式不正确")
            return
        }
        importSummary = String(
            format: NSLocalizedString("import_result_format", comment: "Import result summary"),
            result.added,
            result.skipped
        )
    }

    /// 重启应用以应用语言设置。
    /// 使用 NSWorkspace 启动新实例（沙盒下执行 /usr/bin/open 会被拒绝且静默失败）；
    /// 只有新实例启动成功才退出当前实例，失败则保持运行并提示。
    private func restartApp() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("重启失败: \(error.localizedDescription)")
                    restartFailed = true
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(QuickOpenerApp.sharedModelContainer)
        .environmentObject(QuickOpenerApp.dataManager)
        .environmentObject(ThemeManager.shared)
}
