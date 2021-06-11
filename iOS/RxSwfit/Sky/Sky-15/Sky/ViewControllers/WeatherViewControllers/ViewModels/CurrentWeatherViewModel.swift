//
//  CurrentWeatherViewModel.swift
//  Sky
//
//  Created by Mars on 12/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

struct CurrentWeatherViewModel {
    var weather: WeatherData
    
    var temperature: String {
        let value = weather.currently.temperature
        
        switch UserDefaults.temperatureMode() {
        case .fahrenheit:
            return String(format: "%.1f °F", value)
        case .celsius:
            return String(format: "%.1f °C", value.toCelsius())
        }
    }
    
    var weatherIcon: UIImage {
        return UIImage.weatherIcon(of: weather.currently.icon)!
    }
    
    var humidity: String {
        return String(
            format: "%.1f %%",
            weather.currently.humidity * 100)
    }
    
    var summary: String {
        return weather.currently.summary
    }
    
    var date: String {
        let formatter = DateFormatter()
        formatter.dateFormat = UserDefaults.dateMode().format
        
        return formatter.string(from: weather.currently.time)
    }
    
    static let empty = CurrentWeatherViewModel(weather: .empty)
    
    var isEmpty: Bool {
        return self.weather == WeatherData.empty
    }
    
    static let invalid = CurrentWeatherViewModel(weather: .invalid)
    
    var isInvalid: Bool {
        return self.weather == WeatherData.invalid
    }
}
