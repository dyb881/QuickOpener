//
//  SettingsView.swift
//  ProjectOpener
//
//  Created by 邓耀彬 on 2025/9/26.
//

import AppKit
import KeyboardShortcuts
import SwiftData
import SwiftUI

struct SettingsView: View {
    // "" 代表系统默认
    @AppStorage("appLanguage") private var appLanguage: String = ""

    /// 自动重启失败时提示用户，避免点了按钮后应用直接退出。
    @State private var restartFailed = false

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
}
