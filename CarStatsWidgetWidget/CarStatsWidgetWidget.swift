//
//  CarStatsWidgetWidget.swift
//  CarStatsWidgetWidget
//
//  Created by Surya Vardhan on 05/09/26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            reading: SOCReading(
                soc: 94.7,
                lastUpdated: Date()
            ),
            configuration: ConfigurationAppIntent()
        )
    }

    func snapshot(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> SimpleEntry {

        SimpleEntry(
            date: Date(),
            reading: SOCReadingStore().load(),
            configuration: configuration
        )
    }

    func timeline(
        for configuration: ConfigurationAppIntent,
        in context: Context
    ) async -> Timeline<SimpleEntry> {

        let reading = SOCReadingStore().load()

        let entry = SimpleEntry(
            date: Date(),
            reading: reading,
            configuration: configuration
        )

        // The app requests an immediate widget refresh when a new
        // SOC value is saved. This is only a fallback refresh.
        let nextRefresh = Date().addingTimeInterval(15 * 60)

        return Timeline(
            entries: [entry],
            policy: .after(nextRefresh)
        )
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let reading: SOCReading?
    let configuration: ConfigurationAppIntent
}

struct CarStatsWidgetWidgetEntryView: View {
    var entry: Provider.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Header
            HStack {
                Text("CarSOC")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()

                Image(systemName: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            }

            Spacer(minLength: 8)

            if let reading = entry.reading {

                // Current SOC
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(String(format: "%.1f", reading.soc))
                        .font(
                            .system(
                                size: 42,
                                weight: .bold,
                                design: .rounded
                            )
                        )
                        .minimumScaleFactor(0.7)

                    Text("%")
                        .font(
                            .system(
                                size: 20,
                                weight: .semibold,
                                design: .rounded
                            )
                        )
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                // Time when this SOC value was recorded
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last recorded")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(
                        reading.lastUpdated,
                        format: .dateTime
                            .day()
                            .month(.abbreviated)
                            .hour()
                            .minute()
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .minimumScaleFactor(0.75)
                }

            } else {

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Image(
                        systemName:
                            "antenna.radiowaves.left.and.right"
                    )
                    .font(.title3)

                    Text("No SOC data")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Connect to the vehicle")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding()
        .containerBackground(
            .fill.tertiary,
            for: .widget
        )
    }
}

struct CarStatsWidgetWidget: Widget {

    let kind: String = "CarStatsWidgetWidget"

    var body: some WidgetConfiguration {

        AppIntentConfiguration(
            kind: kind,
            intent: ConfigurationAppIntent.self,
            provider: Provider()
        ) { entry in

            CarStatsWidgetWidgetEntryView(
                entry: entry
            )
        }
        .configurationDisplayName("CarSOC")
        .description(
            "Shows the latest Tata Nexon EV battery state of charge."
        )
        .supportedFamilies([
            .systemSmall,
            .systemMedium
        ])
    }
}

#Preview(as: .systemSmall) {
    CarStatsWidgetWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        reading: SOCReading(
            soc: 94.7,
            lastUpdated: .now
        ),
        configuration: ConfigurationAppIntent()
    )
}
