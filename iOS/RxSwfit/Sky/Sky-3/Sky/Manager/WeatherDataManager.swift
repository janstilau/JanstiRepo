//
//  WeatherDataManager.swift
//  Sky
//
//  Created by Mars on 29/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

// Session 的作用, 是开启一个请求.
// DataTask 的作用, 是具体进行一次请求, 并且完成请求过程中的逻辑.
// 将 Session, DataTask 进行接口化, 使得这里, 进行接口替换成为了可能.

/*
 WeathreDataManager
 Session
 DataTask
 这三者, 各自有着各自的责任.
 将网络请求, 从之前 OC 时代都写到了一个方法内部, 拆到了三个部分, 也就有了替换的可能性.
 在单元测试里面, 就是这种替换性, 在不改变 DataManager 的同时, 完成了 Mock 的行为.
 */

enum DataManagerError: Error {
    case failedRequest
    case invalidResponse
    case unknown
}

internal class DarkSkyURLSession: URLSessionProtocol {
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping DataTaskHandler)
        -> URLSessionDataTaskProtocol {
            return DarkSkyURLSessionDataTask(request: request, completion: completionHandler)
    }
}

internal class DarkSkyURLSessionDataTask: URLSessionDataTaskProtocol {
    private let request: URLRequest
    private let completion: URLSessionProtocol.DataTaskHandler
    
    init(request: URLRequest, completion: @escaping URLSessionProtocol.DataTaskHandler) {
        self.request = request
        self.completion = completion
    }
    
    func resume() {
        let json = ProcessInfo.processInfo.environment["FakeJSON"]
        
        if let json = json {
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)
            let data = json.data(using: .utf8)!
            
            completion(data, response, nil)
        }
    }
}

internal struct Config {
    private static func isUITesting() -> Bool {
        return ProcessInfo.processInfo.arguments.contains("UI-TESTING")
    }
    
    static var urlSession: URLSessionProtocol = {
        if isUITesting() {
            return DarkSkyURLSession()
        }
        else {
            return URLSession.shared
        }
    }()
}

// 一个网络请求, 是一个业务类.
// 这个业务类没有复用的必要性, 就是单纯的某个特定业务的封装而已.
//
final class WeatherDataManager {
    private let baseURL: URL
    internal let urlSession: URLSessionProtocol
    
    // UrlSession, 从一个具体的类型, 变为一个接口对象.
    // 在使用的时候, 依赖于接口进行调用.
    // 在 init 方法里面, 传入实际创建的接口对象.
    // 这样, 才能完成单元测试的 mock 功能.
    // 这也是面向抽象编程的应用, 虽然实际上我们只有一个对象在业务代码里面使用, 但在 mock 的时候, 使用抽象的接口, 使得有了变化的可能性.
    internal init(baseURL: URL, urlSession: URLSessionProtocol) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }
    
    static let shared = WeatherDataManager(baseURL: API.authenticatedURL,
                                           urlSession: Config.urlSession)
    
    typealias CompletionHandler = (WeatherData?, DataManagerError?) -> Void
    
    // 专门的一个函数, 这个函数将网络请求的参数, 通过参数传递过来.
    // 在函数的内部, 进行 request 的参数的拼接工作.
    // 从这里看, 是将原来的, 参数拼接的过程, 从 VC, 或者 View 里面, 专门的转移到了网络交互类了.
    func weatherDataAt(latitude: Double, longitude: Double, completion: @escaping CompletionHandler) {
        let url = baseURL.appendingPathComponent("\(latitude),\(longitude)")
        var request = URLRequest(url: url)
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "GET"
        
        // 真正的网络请求的开启的地方.
        self.urlSession.dataTask(with: request, completionHandler: {
            (data, response, error) in
                self.didFinishGettingWeatherData(data: data, response: response, error: error, completion: completion)
        }).resume()
    }
    
    // 这里是网络请求的解析部分.
    // 应该写到网络层里面, 作为通用的逻辑来复用.
    func didFinishGettingWeatherData(data: Data?,
                                     response: URLResponse?,
                                     error: Error?,
                                     completion: CompletionHandler) {
        if let _ = error {
            completion(nil, .failedRequest)
        }
        else if let data = data, let response = response as? HTTPURLResponse {
            if response.statusCode == 200 {
                do {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .secondsSince1970
                    let weatherData = try decoder.decode(WeatherData.self, from: data)
                    
                    completion(weatherData, nil)
                }
                catch {
                    completion(nil, .invalidResponse)
                }
            }
            else {
                completion(nil, .failedRequest)
            }
        }
        else {
            completion(nil, .unknown)
        }
    }
}
