//
//  URLSession.swift
//  Sky
//
//  Created by Mars on 30/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

// 让原始的 URLSession, 成为 URLSessionProtocol 的实现者.
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
