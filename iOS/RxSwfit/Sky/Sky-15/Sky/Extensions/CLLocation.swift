//
//  CLLocation.swift
//  Sky
//
//  Created by Mars on 13/02/2018.
//  Copyright © 2018 Mars. All rights reserved.
//

import Foundation
import CoreLocation

extension CLLocation {
    var toString: String {
        let latitude = String(format: "%.3f", coordinate.latitude)
        let longitude = String(format: "%.3f", coordinate.longitude)
        
        return "\(latitude), \(longitude)"
    }
}
