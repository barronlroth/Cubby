//
//  Item.swift
//  Cubby
//
//  Created by Barron Roth on 8/16/25.
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
