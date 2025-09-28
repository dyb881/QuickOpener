//
//  QuickOpenerApp.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import SwiftData
import SwiftUI

@main
struct QuickOpenerApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ApplicationModel.self,
            ProjectModel.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
