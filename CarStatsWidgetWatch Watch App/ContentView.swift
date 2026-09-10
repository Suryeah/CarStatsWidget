//
//  ContentView.swift
//  CarStatsWidgetWatch Watch App
//
//  Created by Surya Vardhan on 07/09/26.
//

import SwiftUI

struct WatchContentView: View {

    @State private var soc: Double = 0
    @State private var lastUpdated: Date?
    @State private var isConnected = false

    var body: some View {

        VStack(spacing: 6) {

            Text("CarSOC")
                .font(.headline)

            if let lastUpdated {

                Text(
                    String(
                        format: "%.1f%%",
                        soc
                    )
                )
                .font(
                    .system(
                        size: 34,
                        weight: .bold,
                        design: .rounded
                    )
                )

                HStack(spacing: 4) {

                    Circle()
                        .fill(
                            isConnected
                            ? .green
                            : .red
                        )
                        .frame(
                            width: 6,
                            height: 6
                        )

                    Text(
                        isConnected
                        ? "Connected"
                        : "Disconnected"
                    )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Text(
                    lastUpdated,
                    style: .time
                )
                .font(.caption2)
                .foregroundStyle(.secondary)

            } else {

                Text("--%")
                    .font(
                        .system(
                            size: 34,
                            weight: .bold,
                            design: .rounded
                        )
                    )

                Text("Waiting for iPhone")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    WatchContentView()
}
