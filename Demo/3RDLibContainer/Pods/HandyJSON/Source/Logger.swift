//
//  Logger.swift
//  HandyJSON
//
//  Created by zhouzhuo on 08/01/2017.
//


// 很简单的处理, 如果当前的 log 等级, 小于方法指定的等级, 就打印.
// 这样, 当设置高等级的 log 输出时, debug 等信息, 不会占用 log 日志.
struct InternalLogger {

    static func logError(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if HandyJSONConfiguration.debugMode.rawValue <= DebugMode.error.rawValue {
            print(items, separator: separator, terminator: terminator)
        }
    }

    static func logDebug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if HandyJSONConfiguration.debugMode.rawValue <= DebugMode.debug.rawValue {
            print(items, separator: separator, terminator: terminator)
        }
    }

    static func logVerbose(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        if HandyJSONConfiguration.debugMode.rawValue <= DebugMode.verbose.rawValue {
            print(items, separator: separator, terminator: terminator)
        }
    }
}
