//
//  SettingsView.swift
//  ProjectOpener
//
//  Created by 邓耀彬 on 2025/9/26.
//

import KeyboardShortcuts
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("快捷键设置").font(.headline)) {
                HStack {
                    Text("快捷键：")
                    KeyboardShortcuts.Recorder(for: .toggleProjectOpener)
                    Button("重置快捷键") {
                        KeyboardShortcuts.reset(.toggleProjectOpener)
                    }
                }
            }.padding(.vertical, 5)
            Section(header: Text("应用说明").font(.headline)) {
                Text("快速启动和管理您的项目")
                    .foregroundColor(.secondary)
                Text("使用全局快捷键 (默认 Option+Z) 随时打开项目选择窗口，提升工作效率。")
                    .foregroundColor(.secondary)
            }.padding(.vertical, 5)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
