//
//  MockURLSession.swift
//  SkyTests
//
//  Created by Mars on 02/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation
@testable import Sky

class MockURLSession: URLSessionProtocol {
    var responseHeader: HTTPURLResponse?
    var responseData: Data?
    var responseError: Error?
    var sessionDataTask = MockURLSessionDataTask()
    
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping DataTaskHandler)
        -> URLSessionDataTaskProtocol {
        completionHandler(responseData, responseHeader, responseError)
        return sessionDataTask
    }
}
