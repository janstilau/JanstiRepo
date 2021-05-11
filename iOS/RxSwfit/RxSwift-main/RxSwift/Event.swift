//
//  Event.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents a sequence event.
///
/// Sequence grammar: 
/// **next\* (error | completed)**
@frozen public enum Event<Element> {
    /// Next element is produced.
    case next(Element)

    /// Sequence terminated with an error.
    case error(Swift.Error)

    /// Sequence completed successfully.
    case completed
}

// 对于单个协议的实现, 单独一个 extension 进行包裹.
extension Event: CustomDebugStringConvertible {
    /// Description of event.
    public var debugDescription: String {
        switch self {
        case .next(let value):
            return "next(\(value))"
        case .error(let error):
            return "error(\(error))"
        case .completed:
            return "completed"
        }
    }
}

// 为 Event 增加一些便于使用的计算属性, 方法.
extension Event {
    /// Is `completed` or `error` event.
    public var isStopEvent: Bool {
        switch self {
        case .next: return false
        case .error, .completed: return true
        }
    }

    /// If `next` event, returns element value.
    // 提取 next 里面的数据.
    public var element: Element? {
        if case .next(let value) = self {
            return value
        }
        return nil
    }

    /// If `error` event, returns error.
    // 提取 error 里面的出错信息
    public var error: Swift.Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }

    /// If `completed` event, returns `true`.
    // 提取 complete 的信息
    public var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}

extension Event {
    /// Maps sequence elements using transform. If error happens during the transform, `.error`
    /// will be returned as value.
    // Rx 里面, 根据 event 的 case 进行处理是一个非常普遍的行为.
    // 各种 transform, 都是在特定的 case 上执行, 在其他的 case 上, 仅仅是对于原有值的传递而已.
    // 大部分情况, 都是在 next 上进行操作. 也有 error 这种 transform, 将 error 替换为特殊的 next 的值.
    // 这里, 是 event 上的 map 操作, 是直接的数据的映射. 而不是 operator.
    // 当有错误发生的时候, 自动将 case 映射到 error 这个分类上.
    public func map<Result>(_ transform: (Element) throws -> Result) -> Event<Result> {
        do {
            switch self {
            case let .next(element):
                return .next(try transform(element))
            case let .error(error):
                return .error(error)
            case .completed:
                return .completed
            }
        }
        catch let e {
            return .error(e)
        }
    }
}

// 这种, convertible 是一个常见的命名方式.
// Alamofire 里面, 也是经常使用这种方案.
// 对于这种, 唯一的要求, 就是提供一个 get 方法, 将本身的数据, 转化到对应的类型的数据.
/// A type that can be converted to `Event<Element>`.
public protocol EventConvertible {
    /// Type of element in event
    associatedtype Element

    /// Event representation of this instance
    var event: Event<Element> { get }
}

extension Event: EventConvertible {
    /// Event representation of this instance
    public var event: Event<Element> { self }
}
