//
//  XCTestCase.swift
//  SkyTests
//
//  Created by Mars on 11/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import XCTest

/*
 
 测试过程要不依赖于任何外部条件和系统；
 在任何环境、测试任意多次，结果应该保持不变
 
 */

extension XCTestCase {
    // 这是 XCTestCase 的分类, 所以可以在各个测试用例类中直接使用.
    func loadDataFromBundle(ofName name: String, ext: String) -> Data {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: name, withExtension: ext)
        return try! Data(contentsOf: url!)
    }
}
