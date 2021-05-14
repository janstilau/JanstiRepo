//
//  CurrentWeatherUITests.swift
//  SkyUITests
//
//  Created by Mars on 16/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import XCTest
@testable import Sky

class CurrentWeatherUITests: XCTestCase {
    let app = XCUIApplication()
    var json: String!
    
    
    override func setUp() {
        super.setUp()
        
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        // UI tests must launch the application that they test. Doing this in setup will make sure it happens for each test method.
        app.launchArguments += ["UI-TESTING"]
        
        let json = """
        {
            "longitude" : 100,
            "latitude" : 52,
            "currently" : {
                "temperature" : 23,
                "humidity" : 0.91,
                "icon" : "snow",
                "time" : 1507180335,
                "summary" : "Light Snow"
            }
        }
        """
        app.launchEnvironment["FakeJSON"] = json
        
        app.launch()

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_location_button_exists() {
        let locationBtn = app.buttons["LocationBtn"]
        XCTAssert(locationBtn.exists)
    }
    
    func test_currently_weather_display() {
        XCTAssert(app.images["snow"].exists)
        XCTAssert(app.staticTexts["Light Snow"].exists)
        
    }
}
