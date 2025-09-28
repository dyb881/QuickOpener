//
//  DataManager.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import Combine
import SwiftData

class DataManager: ObservableObject {
    @Published var isDarkMode: Bool = false

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}
