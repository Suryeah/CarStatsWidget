//
//  VehicleManager.swift
//  CarStatsWidget
//
//  Created by Surya Vardhan on 25/08/26.
//

import Foundation
import SwiftUI
import WidgetKit

@Observable
final class VehicleManager {

    var state: VehicleState = .initial

    private let socStore = SOCReadingStore()

    init() {
        // Restore the last persisted SOC when the app launches.
        // This keeps the Home screen consistent with the widget.
        if let reading = socStore.load() {
            state.soc = reading.soc
            state.lastUpdated = reading.lastUpdated
            state.isConnected = false
        }
    }

    func updateSOC(_ soc: Double) {
        guard (0...100).contains(soc) else {
            return
        }

        // Only create a new "last recorded" timestamp when the
        // actual SOC value changes. Repeated polling of the same
        // value should not make the widget appear freshly updated.
        let socChanged = soc != state.soc

        state.soc = soc
        state.isConnected = true

        guard socChanged else {
            return
        }

        let now = Date()
        state.lastUpdated = now

        // Persist the latest changed SOC for the Widget Extension.
        guard socStore.save(soc: soc, at: now) != nil else {
            return
        }

        // Ask WidgetKit to refresh this widget immediately.
        // WidgetKit still controls the actual refresh timing.
        WidgetCenter.shared.reloadTimelines(
            ofKind: "CarStatsWidgetWidget"
        )
    }

    func simulateSOCChange() {

        state.soc -= 1

        if state.soc < 0 {
            state.soc = 100
        }

        let now = Date()
        state.lastUpdated = now
        state.isConnected = true

        // Keep the widget consistent with the simulated app value.
        if socStore.save(soc: state.soc, at: now) != nil {
            WidgetCenter.shared.reloadTimelines(
                ofKind: "CarStatsWidgetWidget"
            )
        }
    }
}
