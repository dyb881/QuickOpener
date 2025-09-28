//
//  Item.swift
//  QuickOpener
//
//  Created by 邓耀彬 on 2025/9/28.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
