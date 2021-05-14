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
// ------------ DO NOT NEED THESE CODES ANYMORE --------------
//    var location: Location! {
//        didSet {
//            if location != nil {
//                self.isLocationReady = true
//            }
//            else {
//                self.isLocationReady = false
//            }
//        }
//    }
//    
//    var weather: WeatherData! {
//        didSet {
//            if weather != nil {
//                self.isWeatherReady = true
//            }
//            else {
//                self.isWeatherReady = false
//            }
//        }
//    }
//    
//    var isLocationReady = false
//    var isWeatherReady = false
//    
//    var isUpdateReady: Bool {
//        return isLocationReady && isWeatherReady
//    }
//    
//    var city: String {
//        return location.name
//    }
// ------------ DO NOT NEED THESE CODES ANYMORE --------------
    
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
    
    static let empty = CurrentWeatherViewModel(
        weather: WeatherData.empty)
    
    var isEmpty: Bool {
        return self.weather == WeatherData.empty
    }
}
