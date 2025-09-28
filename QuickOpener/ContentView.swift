//
//  ContentView.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var applications: [ApplicationModel]
    @State private var filterText: String = ""

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
            TextField("过滤项目", text: $filterText)
            // addProjectButton
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(QuickOpenerApp.sharedModelContainer)
        .environmentObject(QuickOpenerApp.dataManager)
}
