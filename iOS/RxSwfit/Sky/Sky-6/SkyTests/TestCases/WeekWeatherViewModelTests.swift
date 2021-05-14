//
//  WeekWeatherViewModelTests.swift
//  SkyTests
//
//  Created by Mars on 12/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import XCTest
@testable import Sky

class WeekWeatherViewModelTests: XCTestCase {
    var vm: WeekWeatherViewModel!
    
    override func setUp() {
        super.setUp()
        
        let data = loadDataFromBundle(ofName: "DarkSky", ext: "json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let weatherData = try! decoder.decode(WeatherData.self, from: data)
        
        vm = WeekWeatherViewModel(weatherData: weatherData.daily.data)
    }
    
    override func tearDown() {
        super.tearDown()
        
        vm = nil
        UserDefaults.standard.removeObject(
            forKey: UserDefaultsKeys.dateMode)
        UserDefaults.standard.removeObject(
            forKey: UserDefaultsKeys.temperatureMode)
    }
    
    func test_number_of_sections() {
        XCTAssertEqual(vm.numberOfSections, 1)
    }
    
    func test_number_of_days() {
        XCTAssertEqual(vm.numberOfDays, 1)
    }
    
    func test_view_model_for_index() {
        let viewModel = vm.viewModel(for: 0)
        
        XCTAssertEqual(viewModel.date, "October 5")
        XCTAssertEqual(viewModel.week, "Thursday")
    }
}
