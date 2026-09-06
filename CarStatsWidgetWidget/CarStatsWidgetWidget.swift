//
//  CarStatsWidgetWidget.swift
//  CarStatsWidgetWidget
//
//  Created by Surya Vardhan on 05/09/26.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Provider

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

        let nextRefresh = Date().addingTimeInterval(
            15 * 60
        )

        return Timeline(
            entries: [entry],
            policy: .after(nextRefresh)
        )
    }
}

// MARK: - Timeline Entry

struct SimpleEntry: TimelineEntry {

    let date: Date
    let reading: SOCReading?
    let configuration: ConfigurationAppIntent
}

// MARK: - Main Widget View

struct CarStatsWidgetWidgetEntryView: View {

    var entry: Provider.Entry

    @Environment(\.widgetFamily)
    private var widgetFamily

    var body: some View {

        Group {

            switch widgetFamily {

            case .accessoryCircular:
                LockScreenCircularView(
                    entry: entry
                )

            case .accessoryRectangular:
                LockScreenRectangularView(
                    entry: entry
                )

            default:
                HomeScreenView(
                    entry: entry
                )
            }
        }

        // IMPORTANT:
        // This must exist on the top-level widget view so that
        // accessoryCircular and accessoryRectangular widgets
        // also satisfy WidgetKit's container-background requirement.
        .containerBackground(
            .fill.tertiary,
            for: .widget
        )
    }
}

// MARK: - Home Screen Widget

struct HomeScreenView: View {

    var entry: Provider.Entry

    var body: some View {

        VStack(alignment: .leading, spacing: 0) {

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

                HStack(
                    alignment: .firstTextBaseline,
                    spacing: 2
                ) {

                    Text(
                        String(
                            format: "%.1f",
                            reading.soc
                        )
                    )
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

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {

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

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {

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
    }
}

// MARK: - Lock Screen Circular

struct LockScreenCircularView: View {

    var entry: Provider.Entry

    var body: some View {

        if let reading = entry.reading {

            Text(
                String(
                    format: "%.0f%%",
                    reading.soc
                )
            )
            .font(.headline)
            .fontWeight(.bold)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .allowsTightening(true)

        } else {

            Image(
                systemName: "battery.0percent"
            )
            .font(.headline)
        }
    }
}
// MARK: - Lock Screen Rectangular

struct LockScreenRectangularView: View {

    var entry: Provider.Entry

    var body: some View {

        if let reading = entry.reading {

            HStack(
                alignment: .center,
                spacing: 8
            ) {

                VStack(
                    alignment: .leading,
                    spacing: 0
                ) {

                    Text("CAR SOC")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(
                        String(
                            format: "%.1f%%",
                            reading.soc
                        )
                    )
                    .font(.headline)
                    .fontWeight(.bold)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                }

                Spacer(minLength: 4)

                VStack(
                    alignment: .trailing,
                    spacing: 0
                ) {

                    Text("UPDATED")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    Text(
                        reading.lastUpdated,
                        format: .dateTime
                            .hour()
                            .minute()
                    )
                    .font(.caption)
                    .fontWeight(.medium)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                }
            }

        } else {

            VStack(
                alignment: .leading,
                spacing: 0
            ) {

                Text("CAR SOC")
                    .font(.caption2)
                    .fontWeight(.semibold)

                Text("No data")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Widget Configuration

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
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}

// MARK: - Preview

#Preview(
    "Home Small",
    as: .systemSmall
) {
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

#Preview(
    "Lock Screen Circular",
    as: .accessoryCircular
) {
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

#Preview(
    "Lock Screen Rectangular",
    as: .accessoryRectangular
) {
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
