//
//  MockURLSession.swift
//  SkyTests
//
//  Created by Mars on 02/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation
@testable import Sky

/*
 通过 Expection, 可以达到异步行为的测试.
 但是我们主要测试的, 其实是业务逻辑, 也就是组装网络请求, 得到结果的解析过程. 真正的网络请求其实是不重要的.
 这种时候, Mock 里面提供可以自定义结果的操作, 就像一个异步行为的测试, 变成了同步行为了.
 */


// 通过, 将各种实际业务类进行接口化, 让单元测试里面, 替换对应的接口对象成为了可能.
class MockURLSession: URLSessionProtocol {
    
    // 这几个成员变量, 之所以存在, 就是为了进行自定义的.
    // 自定义这几个成员变量的值, 然后在
    var responseHeader: HTTPURLResponse?
    var responseData: Data?
    var responseError: Error?
    var sessionDataTask = MockURLSessionDataTask()
    
    func dataTask(
        with request: URLRequest,
        completionHandler: @escaping DataTaskHandler)
        -> URLSessionDataTaskProtocol {
        // 对于真实的 Session 来说, 是异步请求, 然后在网络获取数据之后才调用 completionHandler.
        // 对于 Mock 来说, 各种数据其实是我们的成员变量进行配置的, 可以直接在调用的时候, 调用 completionHandler 来处理这些数据.
        completionHandler(responseData, responseHeader, responseError)
        return sessionDataTask
    }
}
