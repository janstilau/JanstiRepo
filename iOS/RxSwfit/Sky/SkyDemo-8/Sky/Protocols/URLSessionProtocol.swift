//
//  URLSessionProtocol.swift
//  Sky
//
//  Created by Mars on 06/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

typealias DataTaskHandler = (Data?, URLResponse?, Error?) -> Void

protocol URLSessionProtocol {
    
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping DataTaskHandler)
        -> URLSessionDataTaskProtocol
}
