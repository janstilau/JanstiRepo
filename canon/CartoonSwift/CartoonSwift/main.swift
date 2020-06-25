//
//  main.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


let rowChar_0:[Character] = ["1","1","1","1","0"]
let rowChar_1:[Character] = ["1","1","1","1","0"]
let rowChar_2:[Character] = ["1","1","1","1","0"]
let rowChar_3:[Character] = ["1","1","1","1","0"]

let rowChas = [rowChar_0, rowChar_1, rowChar_2, rowChar_3]

var aLand = Island()
let result = aLand.numIslands(rowChas)

print("end")
