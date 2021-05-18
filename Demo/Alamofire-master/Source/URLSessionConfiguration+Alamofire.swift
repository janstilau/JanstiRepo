//
//  URLSessionConfiguration+Alamofire.swift
//
//  Copyright (c) 2014-2018 Alamofire Software Foundation (http://alamofire.org/)
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation

// 想要让其他类型, 纳入到 AlamofireExtended 系统, 只需要进行一次声明即可. 因为有着默认的实现.
extension URLSessionConfiguration: AlamofireExtended {}

// 为 AlamofireExtension 添加相关的属性方法的时候, 是限制 ExtendedType.
extension AlamofireExtension where ExtendedType: URLSessionConfiguration {
    // Alamofire's default configuration. Same as `URLSessionConfiguration.default` but adds Alamofire default
    // `Accept-Language`, `Accept-Encoding`, and `User-Agent` headers.
    
    // configuration.headers = .default,
    // 属性和值, 都是定义在 Alamofire 里的.
    public static var `default`: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.headers = .default
        return configuration
    }
}
