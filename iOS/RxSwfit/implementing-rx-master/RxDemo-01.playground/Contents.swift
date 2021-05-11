import Foundation

// MARK: - Event

enum Event<Element> {
    case next(Element) // 一个事件, 带有数据
    case error(Error) // 出错了, 带有出错信息, publisher 序列结束
    case completed // 明确的表示完成, publisher 序列结束.
}

// MARK: - Observer

protocol ObserverType {
    associatedtype Element
    
    // 监听事件
    func on(event: Event<Element>) // 监听以上 enum 代表的三种事件.
}

class Observer<Element>: ObserverType {
    
    // 订阅者如何处理事件的闭包
    private let _handler: (Event<Element>) -> Void
    
    init(_ handler: @escaping (Event<Element>) -> Void) {
        _handler = handler
    }
    
    // 实现 监听事件 的协议，内部处理事件
    func on(event: Event<Element>) {
        // 处理事件
        _handler(event)
    }
}

// MARK: - Observable

protocol ObservableType {
    associatedtype Element
    
    // 订阅操作
    func subscribe<O: ObserverType>(observer: O) where O.Element == Element
}

class Observable<Element>: ObservableType {
    // 定义 发布事件 的闭包
    // 这里面, 存储的是如何操作 Observer.
    // 所谓的发布事件, 就是操作 Observer 的 on Event 方法.
    // 监听者模式, 发布者主动调用监听者的接口来发布事件. 但是从思想上, 是发布者发布时间, 监听者异步监听到了.
    private let _eventGenerator: (Observer<Element>) -> Void
    
    init(_ eventGenerator: @escaping (Observer<Element>) -> Void) {
        _eventGenerator = eventGenerator
    }
    
    // 实现 订阅操作 的协议，内部生成事件
    // Publisher 的输出, 必须和 Observer 的输入是同样的一种类型.
    func subscribe<O: ObserverType>(observer: O) where O.Element == Element {
        _eventGenerator(observer as! Observer<Element>)
    }
}

// 这里, 定义好了如何发布事件.
// 在 subscribe 调用的时候, 这个闭包才会真正的执行.
let observable = Observable<Int> { (observer) in
    print("send 0")
    observer.on(event: .next(0))    // observer.on(event: .next(0).map({ $0 * 2 }))
    print("send 1")
    observer.on(event: .next(1))
    print("send 2")
    observer.on(event: .next(2))
    print("send 3")
    observer.on(event: .next(3))
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        print("send completed")
        observer.on(event: .completed)
    }
}

let observer = Observer<Int> { (event) in
    switch event {
    case .next(let value):
        print("recive \(value)")
    case .error(let error):
        print("recive \(error)")
    case .completed:
        print("recive completed")
    }
}

observable.subscribe(observer: observer)
