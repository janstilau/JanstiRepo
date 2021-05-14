//
//  WeatherData.swift
//  Sky
//
//  Created by Mars on 29/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

struct WeatherData: Codable {
    let latitude: Double
    let longitude: Double
    let currently: CurrentWeather
    
    struct CurrentWeather: Codable {
        let time: Date
        let summary: String
        let icon: String
        let temperature: Double
        let humidity: Double
    }
}
