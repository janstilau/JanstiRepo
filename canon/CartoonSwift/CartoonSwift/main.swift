//
//  main.swift
//  CartoonSwift
//
//  Created by JustinLau on 2020/6/25.
//  Copyright © 2020 JustinLau. All rights reserved.
//

import Foundation


let result = try FileManager.default.contentsOfDirectory(atPath: "/Users/justinlau/JanstiRepo/Code/GNU/CodingInterviewChinese2/")

for aItem in result {
    let fullPath = "/Users/justinlau/JanstiRepo/Code/GNU/CodingInterviewChinese2/\(aItem)"
    if fullPath.hasSuffix("DS_Store") { continue }
    let files = try FileManager.default.contentsOfDirectory(atPath: fullPath)
    for aFile in files {
        let filePath = "\(fullPath)/\(aFile)"
        if filePath.hasSuffix("vcxproj") || filePath.hasSuffix("filters") {
            try FileManager.default.removeItem(atPath: filePath)
        }
    }
}
