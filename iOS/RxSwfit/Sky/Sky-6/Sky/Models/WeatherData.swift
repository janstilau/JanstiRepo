//
//  WeatherData.swift
//  Sky
//
//  Created by Mars on 29/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

// 作为一个 Codable, 可以直接在网络请求返回之后, 解析成为正确类型的数据.
struct WeatherData: Codable {
    
    let latitude: Double
    let longitude: Double
    let currently: CurrentWeather
    let daily: WeekWeatherData
    
    struct CurrentWeather: Codable {
        let time: Date
        let summary: String
        let icon: String
        let temperature: Double
        let humidity: Double
    }
    
    struct WeekWeatherData: Codable {
        let data: [ForecastData]
    }
}

/*
 下面, 对于 Equatable 的适配, 主要是因为, 在 array 里面, 需要使用这个方法, 确定 index 的位置.
 */

extension WeatherData.CurrentWeather: Equatable {
    static func ==(
        lhs: WeatherData.CurrentWeather,
        rhs: WeatherData.CurrentWeather) -> Bool {
        return lhs.time == rhs.time &&
            lhs.summary == rhs.summary &&
            lhs.icon == rhs.icon &&
            lhs.temperature == rhs.temperature &&
            lhs.humidity == rhs.humidity
    }
}

extension WeatherData.WeekWeatherData: Equatable {
    static func ==(
        lhs: WeatherData.WeekWeatherData,
        rhs: WeatherData.WeekWeatherData) -> Bool {
        return lhs.data == rhs.data 
    }
}

extension WeatherData: Equatable {
    static func ==(lhs: WeatherData, rhs: WeatherData) -> Bool {
        return lhs.latitude == rhs.latitude &&
            lhs.longitude == rhs.longitude &&
            lhs.currently == rhs.currently &&
            lhs.daily == rhs.daily
    }
}
