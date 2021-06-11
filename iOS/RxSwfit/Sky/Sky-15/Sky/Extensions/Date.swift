//
//  Date.swift
//  Sky
//
//  Created by Mars on 06/03/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import UIKit

extension Date {
    static func from(string: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-mm-dd"
        dateFormatter.timeZone = TimeZone(abbreviation: "GMT+8:00")
        return dateFormatter.date(from: string)!
    }
}
