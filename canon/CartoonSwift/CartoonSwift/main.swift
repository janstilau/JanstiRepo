//
//  main.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation

var values = [1, 2, 0, 3, 4, 0, 0, 5]
print("Source \(values)")
MoveZero.moveZeroes(&values)
print("Changed \(values)")

values = [2, 3, 1, 0, 0, 0, 5, 6, 2, 0, 2]
print("Source \(values)")
MoveZero.moveZeroes(&values)
print("Changed \(values)")

values = [123, 1, 23, 22, 0, 0, 0, 2, 0]
print("Source \(values)")
MoveZero.moveZeroes(&values)
print("Changed \(values)")

values = [0, 0, 0, 1, 2, 3, 4, 5, 0, 6]
print("Source \(values)")
MoveZero.moveZeroes(&values)
print("Changed \(values)")

values = [1]
print("Source \(values)")
MoveZero.moveZeroes(&values)
print("Changed \(values)")
