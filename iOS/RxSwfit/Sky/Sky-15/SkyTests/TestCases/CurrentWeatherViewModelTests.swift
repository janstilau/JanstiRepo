//
//  CurrentWeatherViewModelTests.swift
//  SkyTests
//
//  Created by Mars on 11/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import XCTest
@testable import Sky

class CurrentWeatherViewModelTests: XCTestCase {
    var vm: CurrentWeatherViewModel!
    
    override func setUp() {
        super.setUp()
        
        let data = loadDataFromBundle(ofName: "DarkSky", ext: "json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let weatherData = try! decoder.decode(WeatherData.self, from: data)
        
        vm = CurrentWeatherViewModel()
        vm.weather = weatherData
        
        let location = Location(
            name: "Test City",
            latitude: 100,
            longitude: 100)
        
        vm.location = location
    }
    
    override func tearDown() {
        super.tearDown()
        
        vm = nil
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.dateMode)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.temperatureMode)
    }
    
    func test_city_name_display() {
        XCTAssertEqual(vm.city, "Test City")
    }
    
    func test_date_display_in_text_mode() {
        let dateMode: DateMode = .text
        UserDefaults.standard.set(dateMode.rawValue, forKey: UserDefaultsKeys.dateMode)
        
        XCTAssertEqual(vm.date, "Thu, 05 October")
    }
    
    func test_date_display_in_digit_mode() {
        let dateMode: DateMode = .digit
        UserDefaults.standard.set(dateMode.rawValue, forKey: UserDefaultsKeys.dateMode)
        
        XCTAssertEqual(vm.date, "T, 10/05")
    }
    
    func test_weather_summary() {
        XCTAssertEqual(vm.summary, "Light Snow")
    }
    
    func test_temperature_display_in_celsius() {
        UserDefaults.standard.set(TemperatureMode.celsius.rawValue, forKey: UserDefaultsKeys.temperatureMode)
        XCTAssertEqual(vm.temperature, "-5.0 °C")
    }
    
    func test_temperature_display_in_fahenheit() {
        UserDefaults.standard.set(TemperatureMode.fahrenheit.rawValue, forKey: UserDefaultsKeys.temperatureMode)
        XCTAssertEqual(vm.temperature, "23.0 °F")
    }
    
    func test_humidity_display() {
        XCTAssertEqual(vm.humidity, "91.0 %")
    }
    
    func test_weather_icon_display() {
        let iconFromViewModel = UIImagePNGRepresentation(vm.weatherIcon)!
        let iconFromTestData = UIImagePNGRepresentation(UIImage(named: "snow")!)!
        
        XCTAssertEqual(vm.weatherIcon.size.width, 128.0)
        XCTAssertEqual(vm.weatherIcon.size.height, 128.0)
        XCTAssertEqual(iconFromViewModel, iconFromTestData)
    }
}
