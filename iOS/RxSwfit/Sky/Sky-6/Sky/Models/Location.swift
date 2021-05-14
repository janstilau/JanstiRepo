//
//  Location.swift
//  Sky
//
//  Created by Mars on 29/09/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation
import CoreLocation

struct Location {
    
    private struct Keys {
        static let name = "name"
        static let latitude = "latitude"
        static let longitude = "longitude"
    }
    
    var name: String
    var latitude: Double
    var longitude: Double
    
    // 在类型的内部, 提供到其他类型的转化方法.
    var location: CLLocation {
        return CLLocation(latitude: latitude, longitude: longitude)
    }
    
    // 在类的内部, 提供到通用的容器类对象的转化方法.
    var toDictionary: [String: Any] {
        return [
            "name": name,
            "latitude": latitude,
            "longitude": longitude
        ]
    }
    
    init(name: String, latitude: Double, longitude: Double) {
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
    }
    
    // 提供从通用容器类的转化方法.
    init?(from dictionary: [String: Any]) {
        guard let name = dictionary[Keys.name] as? String else { return nil }
        guard let latitude = dictionary[Keys.latitude] as? Double else { return nil }
        guard let longitude = dictionary[Keys.longitude] as? Double else { return nil }
    
        self.init(name: name, latitude: latitude, longitude: longitude)
    }
}

extension Location: Equatable {
    static func ==(lhs: Location, rhs: Location) -> Bool {
        return lhs.name == rhs.name &&
            lhs.latitude == rhs.latitude &&
            lhs.longitude == rhs.longitude
    }
}
