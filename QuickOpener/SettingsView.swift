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
                    .foregroundColor(.secondary)
            }.padding(.vertical, 5)
        }
        .padding()
    }
}

#Preview {
    SettingsView()
}
