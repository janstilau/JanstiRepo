//
//  Double.swift
//  Sky
//
//  Created by Mars on 06/10/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

extension Double {
    func toCelsius() -> Double {
        return (self - 32.0) / 1.8
    }
}
