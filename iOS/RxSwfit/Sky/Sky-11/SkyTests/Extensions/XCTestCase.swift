//
//  XCTestCase.swift
//  SkyTests
//
//  Created by Mars on 11/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import XCTest

extension XCTestCase {
    func loadDataFromBundle(ofName name: String, ext: String) -> Data {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: name, withExtension: ext)
        
        return try! Data(contentsOf: url!)
    }
}
