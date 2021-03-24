//
//  Configuration.swift
//  HandyJSON
//
//  Created by zhouzhuo on 08/01/2017.
//

public struct DeserializeOptions: OptionSet {
    public let rawValue: Int

    public static let caseInsensitive = DeserializeOptions(rawValue: 1 << 0)

    public static let defaultOptions: DeserializeOptions = []

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

public enum DebugMode: Int {
    case verbose = 0
    case debug = 1
    case error = 2
    case none = 3
}

// Swift 里面, 可以直接将属性挂钩到类型上, 可以大大的减少单例的使用.
// 其实也确实应该如此, 这份数据, 就是类型相关的数据.
public struct HandyJSONConfiguration {

    private static var _mode = DebugMode.error
    public static var debugMode: DebugMode {
        get {
            return _mode
        }
        set {
            _mode = newValue
        }
    }

    public static var deserializeOptions: DeserializeOptions = .defaultOptions
}
