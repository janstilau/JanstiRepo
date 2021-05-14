//
//  MockURLSession.swift
//  SkyTests
//
//  Created by Mars on 07/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation
@testable import SkyDemo

class MockURLSession: URLSessionProtocol {
    var responseData: Data?
    var responseHeader: HTTPURLResponse?
    var responseError: Error?
    var sessionDataTask = MockURLSessionDataTask()
    
    func dataTask(with request: URLRequest, completionHandler: @escaping DataTaskHandler) -> URLSessionDataTaskProtocol {
        completionHandler(responseData, responseHeader, responseError)
        return sessionDataTask
    }
}
