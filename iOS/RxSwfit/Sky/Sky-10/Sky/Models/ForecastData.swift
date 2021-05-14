//
//  ForecastData.swift
//  Sky
//
//  Created by Mars on 24/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

struct ForecastData: Codable {
    let time: Date
    let temperatureLow: Double
    let temperatureHigh: Double
    let icon: String
    let humidity: Double
}

extension ForecastData: Equatable {
    static func ==(
        lhs: ForecastData,
        rhs: ForecastData) -> Bool {
        return lhs.time == rhs.time &&
            lhs.temperatureLow == rhs.temperatureLow &&
            lhs.temperatureHigh == rhs.temperatureHigh &&
            lhs.icon == rhs.icon &&
            lhs.humidity == rhs.humidity
    }
}
