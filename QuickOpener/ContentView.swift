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
    @State private var hoveredProject: ProjectModel?

    var body: some View {
        VStack {
            headerControls
                .padding([.horizontal, .top])
            projectsList
        }
        .frame(width: 300, height: 500)
    }

    private var headerControls: some View {
        HStack {
            TextField("过滤项目", text: $dataManager.filterText)
            addProjectButton
        }
    }

    private func appButton(_ app: ApplicationModel, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(nsImage: app.icon)
            Text(app.name)
        }
        .onHover(perform: updateCursor)
    }

    private var addProjectButton: some View {
        Menu {
            Text("启动应用")
            appButton(dataManager.currentApplication) {
                // 无需执行
            }

            Text("可用应用")
            ForEach(dataManager.applications.filter { $0.path != dataManager.currentApplication.path }, id: \.id) { app in
                appButton(app) {
                    dataManager.selectApplication(app)
                }
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
            dataManager.addProjects()
        }
        .id(dataManager.currentApplication.id)
        .onHover(perform: updateCursor)
    }

    private func projectSetting(_ item: ProjectModel) -> some View {
        ZStack {
            Menu {
                Text("默认启动")
                appButton(item.application) {
                    item.open()
                }
                Text("可用应用")
                ForEach(dataManager.applications.filter { $0.path != item.application.path }, id: \.self) { app in
                    appButton(app) {
                        item.open(app)
                    }
                }
                Text("操作")
                Button(action: {
                    dataManager.removeProjects(item)
                }) {
                    Image(systemName: "trash")
                    Text("删除项目")
                }
                .onHover(perform: updateCursor)
            } label: {
                Image(nsImage: item.application.icon)
            }
            .frame(width: 20, height: 20)
            .clipped()
            .cornerRadius(5)
            Image(nsImage: item.application.icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .allowsHitTesting(false)
        }
    }

    private var projectsList: some View {
        List(dataManager.renderProjects, id: \.self) { item in
            HStack {
                projectSetting(item)
                Text(item.name)
                Spacer()
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                hoveredProject = hovering ? item : nil
                updateCursor(isHovering: hovering)
            }
            .onTapGesture {
                item.open()
            }
            .listRowBackground(hoveredProject == item ? Color.blue.opacity(0.1) : Color.clear)
        }
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
