//
//  WeatherDataManagerTest.swift
//  SkyTests
//
//  Created by Mars on 29/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import XCTest
@testable import SkyDemo

class WeatherDataManagerTest: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func test_weatherDataAt_starts_the_session() {
        let session = MockURLSession()
        let dataTask = MockURLSessionDataTask()
        
        session.sessionDataTask = dataTask
        
        let manager = WeatherDataManager(
            baseURL: URL(string: "https://darksky.net")!,
            urlSession: session)
        
        manager.weatherDataAt(latitude: 52, longitude: 100, completion: { _, _ in })
        
        XCTAssert(session.sessionDataTask.isResumeCalled)
    }
    
    func test_weatherDataAt_gets_data() {
        let expect = expectation(description: "Loading data form \(API.authenticatedURL)")
        var data: WeatherData? = nil
        
        WeatherDataManager.shared.weatherDataAt(latitude: 52, longitude: 100, completion: { (response, error) in
            data = response
            expect.fulfill()
        })
        
        waitForExpectations(timeout: 5, handler: nil)
        XCTAssertNotNil(data)
    }
    
    func test_weatherDataAt_handle_invalid_requeset() {
        let session  = MockURLSession()
        session.responseError = NSError(
            domain: "Invalid Request",
            code: 100,
            userInfo: nil)
        
        let manager = WeatherDataManager(
            baseURL: URL(string: "https://darksky.net")!,
            urlSession: session)
        
        var error: DataManagerError? = nil
        manager.weatherDataAt(latitude: 52, longitude: 100, completion: { (_, e) in error = e })
        
        XCTAssertEqual(error, DataManagerError.failedRequest)
    }
    
    func test_weatherDataAt_handle_statuscode_not_equal_to_200() {
        let session = MockURLSession()
        session.responseHeader = HTTPURLResponse(
            url: URL(string: "https://darksky.net")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil)
        
        let data = "{}".data(using: .utf8)!
        session.responseData = data
        
        let manager = WeatherDataManager(
            baseURL: URL(string: "https://darksky.net")!,
            urlSession: session)
        
        var error: DataManagerError? = nil
        
        manager.weatherDataAt(latitude: 52, longitude: 100, completion: { (_, e) in error = e })
        
        XCTAssertEqual(error, DataManagerError.failedRequest)
    }
    
    func test_weatherDataAt_handle_invalid_response() {
        let session = MockURLSession()
        session.responseHeader = HTTPURLResponse(
            url: URL(string: "https://darksky.net")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)
        
        let data = "{".data(using: .utf8)!
        session.responseData = data
        
        let manager = WeatherDataManager(
            baseURL: URL(string: "https://darksky.net")!,
            urlSession: session)
        
        var error: DataManagerError? = nil
        
        manager.weatherDataAt(latitude: 52, longitude: 100, completion: { (_, e) in error = e })
        
        XCTAssertEqual(error, DataManagerError.invalidResponse)
    }
    
    func test_weatherDataAt_handle_response_decode() {
        let session = MockURLSession()
        session.responseHeader = HTTPURLResponse(
            url: URL(string: "https://darksky.net")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)
        
        let data = """
        {
            "longitude" : 100,
            "latitude" : 52,
            "currently" : {
                "temperature" : 23,
                "humidity" : 0.91,
                "icon" : "snow",
                "time" : 1507180335,
                "summary" : "Light Snow"
            },
            "daily": {
                "data": [
                    {
                        "time": 1507180335,
                        "icon": "clear-day",
                        "temperatureLow": 66,
                        "temperatureHigh": 82,
                        "humidity": 0.25
                    }
                ]
            }
        }
        """.data(using: .utf8)!
        session.responseData = data
        
        var decoded: WeatherData? = nil
        let manager = WeatherDataManager(
            baseURL: URL(string: "https://darksky.net")!,
            urlSession: session)
        
        manager.weatherDataAt(latitude: 52, longitude: 100, completion: { (d, _) in decoded = d })
        
        let expectedWeekData = WeatherData.WeekWeatherData(data: [
            ForecastData(
                time: Date(timeIntervalSince1970: 1507180335),
                temperatureLow: 66,
                temperatureHigh: 82,
                icon: "clear-day",
                humidity: 0.25)
            ])
        
        let expected = WeatherData(
            latitude: 52,
            longitude: 100,
            currently: WeatherData.CurrentWeather(
                time: Date(timeIntervalSince1970: 1507180335),
                summary: "Light Snow",
                icon: "snow",
                temperature: 23,
                humidity: 0.91),
            daily: expectedWeekData)
        
        XCTAssertEqual(decoded, expected)
    }
}













































