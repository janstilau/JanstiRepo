//
//  SettingsTemperatureViewModel.swift
//  SkyTests
//
//  Created by Mars on 11/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import XCTest
@testable import Sky

class SettingsTemperatureViewModelTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.temperatureMode)
    }
    
    func test_temperature_display_in_celsius() {
        let vm = SettingsTemperatureViewModel(temperatureMode: .celsius)
        XCTAssertEqual(vm.labelText, "Celsius")
    }
    
    func test_temperature_display_in_fahrenheit() {
        let vm = SettingsTemperatureViewModel(temperatureMode: .fahrenheit)
        XCTAssertEqual(vm.labelText, "Fahrenheit")
    }
    
    func test_temperature_celsius_selected() {
        let temperatureMode: TemperatureMode = .celsius
        let vm = SettingsTemperatureViewModel(temperatureMode: temperatureMode)
        
        UserDefaults.standard.set(temperatureMode.rawValue,
                                  forKey: UserDefaultsKeys.temperatureMode)
        
        XCTAssertEqual(vm.accessory, UITableViewCellAccessoryType.checkmark)
    }
    
    func test_temperature_celsius_unselected() {
        let temperatureMode: TemperatureMode = .celsius
        let vm = SettingsTemperatureViewModel(temperatureMode: .fahrenheit)
        
        UserDefaults.standard.set(temperatureMode.rawValue,
                                  forKey: UserDefaultsKeys.temperatureMode)
        
        XCTAssertEqual(vm.accessory, UITableViewCellAccessoryType.none)
    }
    
    func test_temperature_fahrenheit_selected() {
        let temperatureMode: TemperatureMode = .fahrenheit
        let vm = SettingsTemperatureViewModel(temperatureMode: temperatureMode)
        
        UserDefaults.standard.set(temperatureMode.rawValue,
                                  forKey: UserDefaultsKeys.temperatureMode)
        
        XCTAssertEqual(vm.accessory, UITableViewCellAccessoryType.checkmark)
    }
    
    func test_temperature_fahrenheit_unselected() {
        let temperatureMode: TemperatureMode = .fahrenheit
        let vm = SettingsTemperatureViewModel(temperatureMode: .celsius)
        
        UserDefaults.standard.set(temperatureMode.rawValue,
                                  forKey: UserDefaultsKeys.temperatureMode)
        
        XCTAssertEqual(vm.accessory, UITableViewCellAccessoryType.none)
    }
}
