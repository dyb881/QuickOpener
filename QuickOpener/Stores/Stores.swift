//
//  Stores.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import AppKit
import Observation
import SwiftData

@Observable class Stores {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
}
