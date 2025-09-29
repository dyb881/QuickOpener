//
//  ContentView.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataManager: DataManager

    var body: some View {
        VStack {
            headerControls
                .padding([.horizontal, .top])
            // projectsList
        }
        .frame(width: 300, height: 500)
    }

    private var headerControls: some View {
        HStack {
            TextField("过滤项目", text: $dataManager.filterText)
            addProjectButton
        }
    }

    private var addProjectButton: some View {
        Menu {
            Text("启动应用")
            Button(action: {}) {
                Image(nsImage: dataManager.currentApplication.icon)
                Text(dataManager.currentApplication.name)
            }
            .onHover(perform: updateCursor)

            Text("可用应用")
            ForEach(dataManager.applications.filter { $0.path != dataManager.currentApplication.path }, id: \.id) { app in
                Button(action: {
                    dataManager.selectApplication(app)
                }) {
                    Image(nsImage: app.icon)
                    Text(app.name)
                }
                .onHover(perform: updateCursor)
            }

            Text("操作")
            Button(action: {
                dataManager.addApplication()
            }) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: "/System/Applications/App Store.app"))
                Text("添加应用")
            }
            .onHover(perform: updateCursor)
        } label: {
            Image(systemName: "plus")
        } primaryAction: {
            // stores.addProjects()
        }
        .onHover(perform: updateCursor)
    }

    private func updateCursor(isHovering: Bool) {
        if isHovering {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.arrow.set()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(QuickOpenerApp.sharedModelContainer)
        .environmentObject(QuickOpenerApp.dataManager)
}
