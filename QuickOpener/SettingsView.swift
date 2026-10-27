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

    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("settings_general")).font(.headline)) {
                Toggle(isOn: $launchAtLogin) {
                    Text(LocalizedStringKey("settings_launch_at_login"))
                }
                .onChange(of: launchAtLogin) { _, enabled in
                    updateLaunchAtLogin(enabled)
                }
            }.padding(.vertical, 5)

            Section(header: Text(LocalizedStringKey("settings_language")).font(.headline)) {
                HStack {
                    Text(LocalizedStringKey("label_language"))
                    Picker("", selection: $appLanguage) {
                        ForEach(languages, id: \.1) { name, code in
                            Text(LocalizedStringKey(name)).tag(code)
                        }
                    }
                    .labelsHidden()
                    .onChange(of: appLanguage) { _, language in
                        // AppleLanguages UserDefaults 是设置每应用语言的唯一方案
                        // macOS 通过 System Settings → Language & Region 也支持每应用语言设置，
                        // 但无公开的编程 API，UserDefaults hack 仍是行业标准做法
                        UserDefaults.standard.set(language.isEmpty ? nil : [language], forKey: "AppleLanguages")
                    }
                    Button(LocalizedStringKey("restart_takes_effect")) {
                        restartApp()
                    }
                }
            }.padding(.vertical, 5)

            Section(header: Text(LocalizedStringKey("settings_shortcuts")).font(.headline)) {
                HStack {
                    Text(LocalizedStringKey("label_shortcut"))
                    KeyboardShortcuts.Recorder(for: .toggleProjectOpener)
                    Button(LocalizedStringKey("button_reset_shortcut")) {
                        KeyboardShortcuts.reset(.toggleProjectOpener)
                    }
                }
            }.padding(.vertical, 5)

            Section(header: Text(LocalizedStringKey("settings_data")).font(.headline)) {
                HStack {
                    Button(LocalizedStringKey("button_export_projects")) {
                        exportProjects()
                    }
                    Button(LocalizedStringKey("button_import_projects")) {
                        importProjects()
                    }
                }
            }.padding(.vertical, 5)

            Section(header: Text(LocalizedStringKey("settings_about")).font(.headline)) {
                Text(LocalizedStringKey("app_description_short"))
                    .foregroundColor(.secondary)
                Text(LocalizedStringKey("app_description_long"))
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.secondary)
            }.padding(.vertical, 5)
        }
        .padding()
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
}
