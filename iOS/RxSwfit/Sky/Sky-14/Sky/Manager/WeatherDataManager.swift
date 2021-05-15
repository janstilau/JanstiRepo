//
//  WeatherDataManager.swift
//  Sky
//
//  Created by Mars on 29/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//
import RxSwift
import RxCocoa
import Foundation

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


// 网络请求的 API 接口实现类.
final class WeatherDataManager {
    private let baseURL: URL
    internal let urlSession: URLSessionProtocol
    
    internal init(baseURL: URL, urlSession: URLSessionProtocol) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }
    
    static let shared = WeatherDataManager(baseURL: API.authenticatedURL, urlSession: Config.urlSession)
    
    typealias CompletionHandler = (WeatherData?, DataManagerError?) -> Void
    
    func weatherDataAt(latitude: Double, longitude: Double) -> Observable<WeatherData> {
        let url = baseURL.appendingPathComponent("\(latitude),\(longitude)")
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpMethod = "GET"
        
        let MAX_ATTEMPTS = 3
        
        return (self.urlSession as! URLSession)
            .rx.data(request: request)
            .map {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .secondsSince1970
                let weatherData = try decoder.decode(WeatherData.self, from: $0)
                
                return weatherData
            }
//            .retry(3)
//            .retry()
            .retryWhen { e in
                e.enumerated() // Observable<Error> -> Observable<(Int, Error)>
                 .flatMap {
                    (attempt, error) -> Observable<Int> in
                
                    if (attempt >= MAX_ATTEMPTS) {
                        print("------------- \(attempt + 1) attempt -------------")
                        return Observable.error(error)
                    }
                    else {
                        // How can we implement the back-off retry strategy?
                        print("------------- \(attempt + 1) Retry --------------")
                        return Observable<Int>.timer(Double(attempt + 1), scheduler: MainScheduler.instance).take(1)
                    }
                }
            }
            .materialize()
            .do(onNext: { print("==== Materialize: \($0) ====") })
            .dematerialize()
            .catchErrorJustReturn(WeatherData.invalid)
    }
}
