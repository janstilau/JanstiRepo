//
//  MockURLSessionDataTask.swift
//  SkyTests
//
//  Created by Mars on 02/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation
@testable import Sky

class MockURLSessionDataTask: URLSessionDataTaskProtocol {
    private (set) var isResumeCalled = false
    
    func resume() {
        self.isResumeCalled = true
    }
}
