//
//  Alamofire.swift
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

/// Reference to `Session.default` for quick bootstrapping and examples.
/*
 通过这种方式, 来获取 Session.default.
 实际上, 就是一个全局变量. 这个全局变量在使用的时候, 才会进行初始化. Swfit 保证, 不会在编译器进行动态数据的初始化, 而是在使用之前在进行初始化.
 所以, 在 Swift 这门语言里面, 不用专门在 load, initilize 方法里面, 专门做一些值的设置的操作.
 */
public let AF = Session.default

/// Current Alamofire version. Necessary since SPM doesn't use dynamic libraries. Plus this will be more accurate.
let version = "5.1.0"
