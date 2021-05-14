//
//  URLSessionProtocol.swift
//  Sky
//
//  Created by Mars on 30/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

protocol URLSessionProtocol {
    typealias DataTaskHandler =
        (Data?, URLResponse?, Error?) -> Void
    
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping DataTaskHandler)
        -> URLSessionDataTaskProtocol
}
