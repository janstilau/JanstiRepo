//
//  URLSession.swift
//  Sky
//
//  Created by Mars on 30/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

// URLSessionProtocol 提供了一层抽象, URLSession 实现了这层抽象.
// 这层抽象, 就是在 URLSession 的功能上提取出来的. 主要是用于在 Test 里面, 进行本地化的测试.
extension URLSession: URLSessionProtocol {
    
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping DataTaskHandler)
        -> URLSessionDataTaskProtocol {
        return (dataTask(
            with: request,
            completionHandler: completionHandler)
            as URLSessionDataTask)
            as URLSessionDataTaskProtocol
    }
    
}
