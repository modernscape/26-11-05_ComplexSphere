//
//  Item.swift
//  26-11-05_ComplexSphere
//
//  Created by forest on 2026/11/08.
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
