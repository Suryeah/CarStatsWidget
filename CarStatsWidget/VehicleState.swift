//
//  VehicleState.swift
//  CarStatsWidget
//
//  Created by Surya Vardhan on 25/08/26.
//

import Foundation

struct VehicleState {
    var soc: Double
    var lastUpdated: Date
    var isConnected: Bool
    
    static let initial = VehicleState(
        soc: 74,
        lastUpdated: Date(),
        isConnected: true
    )
}
