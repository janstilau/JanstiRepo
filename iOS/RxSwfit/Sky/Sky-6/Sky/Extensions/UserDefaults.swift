//
//  UserDefaults.swift
//  Sky
//
//  Created by Mars on 01/12/2017.
//  Copyright © 2017 Mars. All rights reserved.
//

import Foundation

// 其实就是 Int 值, 但是使用 Enum, 让代码更加的清晰.
// 并且, 可以提供方法的实现.
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

// 专门定义一个类型, 用于 UserDefaults 的特殊 key 值的确定.
// Swift 的随时可以定义类型, 并且, 可以将类型的作用发挥的很好.
// 同时, 将相关的值至于特殊的类型的管理下, 也比在实现文件里面, 使用 static const 管理有着更 clean code, 更加灵活的控制方式.
struct UserDefaultsKeys {
    static let dateMode = "dateMode"
    static let locations = "locations"
    static let temperatureMode = "temperatureMode"
}

extension UserDefaults {
    
    // Date
    
    // 对于 Enum 来说, 如果指定了原始类型, 那么自动就有了 rawValue 的实现了.
    // Enum, 具有原始类型, 就是单单当做 case 值做类型区分使用.
    // 如果具有关联值, 就是当做数据容器来进行使用.
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
    
    // toDictionary 使用的意义就在这里.
    // 这个方法, 在 Model 上, 可以方便其他的地方使用.
    
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
    
    // 添加更加方便的方法, 做 add, remove 的操作.
    // 因为需要序列化, 所以是一个代价相对比较大的过程.
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
