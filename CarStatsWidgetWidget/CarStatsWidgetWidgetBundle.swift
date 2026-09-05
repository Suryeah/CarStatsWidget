//
//  CarStatsWidgetWidgetBundle.swift
//  CarStatsWidgetWidget
//
//  Created by Surya Vardhan on 05/09/26.
//

import WidgetKit
import SwiftUI

@main
struct CarStatsWidgetWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarStatsWidgetWidget()
        CarStatsWidgetWidgetControl()
        CarStatsWidgetWidgetLiveActivity()
    }
}
