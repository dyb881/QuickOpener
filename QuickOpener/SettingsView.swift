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
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1, y: 0.5)
                }
            }
            .frame(width: 19, height: 19)
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
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 通用
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

                // 外观：界面模式 + 主题色
                section("settings_appearance") {
                    card {
                        VStack(spacing: 12) {
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

                            Rectangle()
                                .fill(DS.line)
                                .frame(height: 1)

                            HStack {
                                Text(LocalizedStringKey("theme_color"))
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(DS.text)
                                Spacer(minLength: 12)
                                HStack(spacing: 7) {
                                    ForEach(AccentTheme.allCases) { item in
                                        themeSwatch(item)
                                    }
                                }
                            }
                        }
                    }
                }

                // 语言
                section("settings_language") {
                    card {
                        VStack(alignment: .leading, spacing: 10) {
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
                                .frame(width: 170)
                                .onChange(of: appLanguage) { _, language in
                                    // AppleLanguages UserDefaults 是设置每应用语言的唯一方案
                                    UserDefaults.standard.set(language.isEmpty ? nil : [language], forKey: "AppleLanguages")
                                }
                            }
                            Button(LocalizedStringKey("restart_takes_effect")) {
                                restartApp()
                            }
                            .controlSize(.small)
                        }
                    }
                }

                // 快捷键
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

                // 数据
                section("settings_data") {
                    card {
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
                    }
                }

                // 关于
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
                            .frame(width: 44, height: 44)
                            .overlay(
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .strokeBorder(DS.line2, lineWidth: 1)
                            )

                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: "QuickOpener \(appVersion)")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(DS.text)
                                Text(LocalizedStringKey("app_description_short"))
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(DS.text3)
                                Text(LocalizedStringKey("app_description_long"))
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(DS.text3)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .padding(22)
        }
        .frame(width: 520, height: 700)
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
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
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
