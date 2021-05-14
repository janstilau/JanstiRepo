//
//  MockURLSessionDataTask.swift
//  SkyTests
//
//  Created by Mars on 07/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation
@testable import SkyDemo

class MockURLSessionDataTask: URLSessionDataTaskProtocol {
    private (set) var isResumeCalled = false
    
    func resume() {
        self.isResumeCalled = true
    }
}
