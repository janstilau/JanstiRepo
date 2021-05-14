//
//  Double.swift
//  Sky
//
//  Created by Mars on 06/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

// 在 Swfit 里面, 直接在类型上增加方法, 而不是添加很多的工具方法.
extension Double {
    func toCelsius() -> Double {
        return (self - 32.0) / 1.8
    }
}
