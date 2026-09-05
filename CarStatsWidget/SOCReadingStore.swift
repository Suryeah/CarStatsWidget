//
//  SOCReadingStore.swift
//  CarStatsWidget
//
//  Created by Surya Vardhan on 05/09/26.
//

import Foundation

final class SOCReadingStore {
    static let appGroupIdentifier = "group.com.surya.CarStatsWidget"

    private let defaults: UserDefaults?
    private let readingKey = "latestSOCReading"

    init(suiteName: String = SOCReadingStore.appGroupIdentifier) {
        defaults = UserDefaults(suiteName: suiteName)
    }

    func load() -> SOCReading? {
        guard
            let data = defaults?.data(forKey: readingKey),
            let reading = try? JSONDecoder().decode(SOCReading.self, from: data),
            (0...100).contains(reading.soc)
        else {
            return nil
        }

        return reading
    }

    func save(soc: Double, at date: Date = Date()) -> SOCReading? {
        guard (0...100).contains(soc) else {
            return nil
        }

        let reading = SOCReading(soc: soc, lastUpdated: date)

        guard let data = try? JSONEncoder().encode(reading) else {
            return nil
        }

        defaults?.set(data, forKey: readingKey)
        return reading
    }
}
