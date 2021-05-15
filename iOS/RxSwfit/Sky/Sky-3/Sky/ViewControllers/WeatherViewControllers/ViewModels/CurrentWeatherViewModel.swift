//
//  CurrentWeatherViewModel.swift
//  Sky
//
//  Created by Mars on 12/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import UIKit

// CurrentWeatherViewController需要的所有数据，在View Model中都有对应的接口了
struct CurrentWeatherViewModel {
    // ViewModel 里面, 到底需要引用多少数据, 是和 View 的展示需求相关的.
    // View Model 是和业务联系紧密的一个类.
    var location: Location! {
        didSet {
            if location != nil {
                self.isLocationReady = true
            }
            else {
                self.isLocationReady = false
            }
        }
    }
    
    var weather: WeatherData! {
        didSet {
            if weather != nil {
                self.isWeatherReady = true
            }
            else {
                self.isWeatherReady = false
            }
        }
    }
    
    var isLocationReady = false
    var isWeatherReady = false
    
    
    /*
     通过计算属性, 来为 View 提供属性.
     */
    var isUpdateReady: Bool {
        return isLocationReady && isWeatherReady
    }
    
    var city: String {
        return location.name
    }
    
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
}
