//
//  URLSessionProtocol.swift
//  Sky
//
//  Created by Mars on 30/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

// 这个协议, 本身就是 URLSession 抽取出来的一个类. 
protocol URLSessionProtocol {
    typealias DataTaskHandler =
        (Data?, URLResponse?, Error?) -> Void
    
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping DataTaskHandler)
        -> URLSessionDataTaskProtocol
}
