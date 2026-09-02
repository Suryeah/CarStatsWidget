//
//  VehicleManager.swift
//  CarStatsWidget
//
//  Created by Surya Vardhan on 25/08/26.
//

import Foundation
import SwiftUI

@Observable
final class VehicleManager {
    
    var state: VehicleState = .initial
    
    func updateSOC(_ soc: Double) {
        state.soc = soc
        state.lastUpdated = Date()
        state.isConnected = true
    }
    
    func simulateSOCChange() {
        
        state.soc -= 1
        
        if state.soc < 0 {
            state.soc = 100
        }
        
        state.lastUpdated = Date()
    }
}
