//
//  WeatherDataManagerTest.swift
//  SkyTests
//
//  Created by Mars on 30/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import XCTest
@testable import Sky

// WeathreData 的单元测试类.
class WeatherDataManagerTest: XCTestCase {
    let url = URL(string: "https://darksky.net")!
    var session: MockURLSession!
    var manager: WeatherDataManager!
    
    //  这两个方法, 是每次测试用例方法调用前后都会调用的.
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // manager 里面的 sesstion 是 MockSession/
        // MockSession 里面, 产生 MockDataTask. MockDataTask, 提供了测试框架里面, 可以进行 test 的能力.
        self.session = MockURLSession()
        self.manager = WeatherDataManager(baseURL: url, urlSession: session)
    }
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // 这里验证, weatherDataAt 方法, 确实是开启了一个网络请求.
    func test_weatherDataAt_starts_the_session() {
        let dataTask = MockURLSessionDataTask()
        session.sessionDataTask = dataTask
        
        manager.weatherDataAt(
            latitude: 52,
            longitude: 100,
            completion: { _, _ in  })
        
        XCTAssert(session.sessionDataTask.isResumeCalled)
    }
    
    // 这里, 验证, Mock 的数据确实是非法的请求. 响应回调能够正确的解析出错误来.
    func test_weatherData_handle_invalid_request() {
        session.responseError = NSError(
            domain: "Invalid Request", code: 100, userInfo: nil)
        var error: DataManagerError? = nil
        
        manager.weatherDataAt(latitude: 52, longitude: 100, completion: {
            (_, e) in
            error = e
        })
        
        XCTAssertEqual(error, DataManagerError.failedRequest)
    }
    
    
    func test_weatherData_handle_statuscode_not_equal_to_200() {
        session.responseHeader = HTTPURLResponse(
            url: url, statusCode: 400, httpVersion: nil, headerFields: nil)
        
        let data = "{}".data(using: .utf8)!
        session.responseData = data
        
        var error: DataManagerError? = nil
        
        manager.weatherDataAt(latitude: 52, longitude: 100, completion: {
            (_, e) in
            error = e
        })
        
        XCTAssertEqual(error, DataManagerError.failedRequest)
    }
    
    func test_weatherData_handle_invalid_response() {
        session.responseHeader = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil)
        
        let data = "{".data(using: .utf8)!
        session.responseData = data
        
        var error: DataManagerError? = nil
        
        manager.weatherDataAt(
            latitude: 52,
            longitude: 100,
            completion: {
            (_, e) in
            error = e
        })
        
        XCTAssertEqual(error, DataManagerError.invalidResponse)
    }
    
    func test_weatherData_handle_response_decode() {
        session.responseHeader = HTTPURLResponse(
            url: url,
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
        
        manager.weatherDataAt(
            latitude: 52,
            longitude: 100,
            completion: {
                (d, _) in
                decoded = d
        })
       
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
