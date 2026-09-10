//
//  CarStatsWidgetApp.swift
//  CarStatsWidget
//
//  Created by Surya Vardhan on 25/08/26.
//

import SwiftUI
import OSLog
import UIKit

@main
struct CarStatsWidgetApp: App {

    private let logger = Logger(
        subsystem: "com.surya.CarStatsWidget",
        category: "APP"
    )

    init() {
        logger.info("CarStatsWidget application initialized")

        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [logger] _ in
            logger.info("APPLICATION ENTERED BACKGROUND")
        }

        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [logger] _ in
            logger.info("APPLICATION WILL ENTER FOREGROUND")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
