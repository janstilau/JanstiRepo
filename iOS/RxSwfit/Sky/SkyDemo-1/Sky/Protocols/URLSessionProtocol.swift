//
//  URLSessionProtocol.swift
//  Sky
//
//  Created by Mars on 06/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

protocol URLSessionProtocol {
    typealias dataTaskHandler = (Data?, URLResponse?, Error?) -> Void
    
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping dataTaskHandler)
        -> URLSessionDataTaskProtocol
}
