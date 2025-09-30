//
//  SettingsView.swift
//  ProjectOpener
//
//  Created by 邓耀彬 on 2025/9/26.
//

import KeyboardShortcuts
import SwiftData
import SwiftUI

struct SettingsView: View {
    // "" 代表系统默认
    @AppStorage("appLanguage") private var appLanguage: String = ""

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
    }

    private func restartApp() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.terminate(nil)
        }
    }
}

#Preview {
    SettingsView()
}
