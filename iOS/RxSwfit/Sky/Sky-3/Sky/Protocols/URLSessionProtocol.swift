//
//  URLSessionProtocol.swift
//  Sky
//
//  Created by Mars on 30/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

protocol URLSessionProtocol {
    
    // 这个接口, 是完全按照 session 的接口设计的.
    // 大部分情况下, 我们就是使用的 iOS 原生的 URLSession. 
    typealias DataTaskHandler =
        (Data?, URLResponse?, Error?) -> Void
    
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping DataTaskHandler)
        -> URLSessionDataTaskProtocol
}
