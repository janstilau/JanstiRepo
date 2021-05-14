//
//  CurrentWeatherUITests.swift
//  SkyUITests
//
//  Created by Mars on 20/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import XCTest

class CurrentWeatherUITests: XCTestCase {
    
    let app = XCUIApplication()
    
    override func setUp() {
        super.setUp()
        
        continueAfterFailure = false
        
        app.launchArguments += ["UI-TESTING"]
        app.launchEnvironment["FakeJSON"] = """
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
        app.launch()
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_location_button_exists() {
        let locationBtn = app.buttons["LocationBtn"]
//        let exists = NSPredicate(format: "exists == true")
//
//        expectation(for: exists, evaluatedWith: locationBtn, handler: nil)
//        waitForExpectations(timeout: 5, handler: nil)
        
        XCTAssert(locationBtn.exists)
    }
    
    func test_current_weather_display() {
        XCTAssert(app.images["snow"].exists)
        XCTAssert(app.staticTexts["Light Snow"].exists)
    }
    
}




















