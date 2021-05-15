//
//  UserDefaults.swift
//  Sky
//
//  Created by Mars on 01/12/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

// 一个特殊的类型, 其实就是 Int.
// 用 Enum 让代码具有更强的表现性.
enum DateMode: Int {
    case text
    case digit
    
    var format: String {
        return self == .text ? "E, dd MMMM" : "EEEEE, MM/dd"
    }
}

enum TemperatureMode: Int {
    case celsius
    case fahrenheit
}

struct UserDefaultsKeys {
    // 将所有的, UserDefault 需要使用的 key, 全部用 static let 的方式定义在一个特殊的类型里面
    static let dateMode = "dateMode"
    static let locations = "locations"
    static let temperatureMode = "temperatureMode"
}

/*
 这个类, 其实和自己之前处理小红点的编写的工具类是差不多的.
 都是将逻辑封装到了方法内给外界使用.
 */

extension UserDefaults {
    
    // Date
    // 在 UserDefaults 上面, 定义特殊的方法, 进行 DateMode 这个特殊类型的存值和取值.
    
    static func dateMode() -> DateMode {
        let value = UserDefaults.standard.integer(forKey: UserDefaultsKeys.dateMode)
        
        return DateMode(rawValue: value) ?? DateMode.text
    }
    
    static func setDateMode(to value: DateMode) {
        UserDefaults.standard.set(value.rawValue, forKey: UserDefaultsKeys.dateMode)
    }
    
    // Temperature
    
    static func temperatureMode() -> TemperatureMode {
        let value = UserDefaults.standard.integer(forKey: UserDefaultsKeys.temperatureMode)
        
        return TemperatureMode(rawValue: value) ?? TemperatureMode.celsius
    }
    
    static func setTemperatureMode(to value: TemperatureMode) {
        UserDefaults.standard.set(value.rawValue, forKey: UserDefaultsKeys.temperatureMode)
    }
    
    // Locations
    
    static func saveLocations(_ locations: [Location]) {
        let dictionaries: [[String: Any]] = locations.map { $0.toDictionary }
        
        UserDefaults.standard.set(dictionaries, forKey: UserDefaultsKeys.locations)
    }
    
    static func loadLocations() -> [Location] {
        let data = UserDefaults.standard.array(forKey: UserDefaultsKeys.locations)
        guard let dictionaries = data as? [[String: Any]] else {
            return []
        }
        
        // compactMap
        return dictionaries.compactMap {
            return Location(from: $0)
        }
    }
    
    static func addLocation(_ location: Location) {
        var locations = loadLocations()
        locations.append(location)
        
        saveLocations(locations)
    }
    
    static func removeLocation(_ location: Location) {
        var locations = loadLocations()
        
        guard let index = locations.index(of: location) else {
            return
        }
        
        locations.remove(at: index)
        
        saveLocations(locations)
    }
}
