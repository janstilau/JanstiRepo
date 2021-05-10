import Foundation

// MARK: - Event

enum Event<Element> {
    case next(Element) // 真实的数据
    case error(Error) // 产生了错误
    case completed // 结束的标志.
}

// MARK: - Observer

// 订阅者协议. 该协议的 on 函数, 就是发布数据之后的处理方法.
protocol ObserverType {
    associatedtype Element
    
    // 响应事件的发生
    func on(event: Event<Element>)
}

// 实际的 ObserverType 接口的实现者. 提供了配置事件发生回调的能力.
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

// 发布者协议, 必须提供了注册订阅者的能力
protocol ObservableType {
    associatedtype Element
    
    // 订阅操作, 接收一个 ObserverType 接口对象进行处理.
    func subscribe<O: ObserverType>(observer: O) where O.Element == Element
}

// 实际的 ObservableType 实现类, 对于 subscribe 的实现, 也是通过自己保存的闭包实现的.
class Observable<Element>: ObservableType {
    // _eventGenerator 代表的是事件发生器.
    private let _eventGenerator: (Observer<Element>) -> Void
    
    init(_ eventGenerator: @escaping (Observer<Element>) -> Void) {
        _eventGenerator = eventGenerator
    }
    
    // 实现 订阅操作 的协议，内部生成事件
    // 当有响应者注册进来的时候, 就把事件发生器调用一遍
    // 这里仅仅是简单的 Observable 的实现
    func subscribe<O: ObserverType>(observer: O) where O.Element == Element {
        _eventGenerator(observer as! Observer<Element>)
    }
}



// 定义一个发布者. 闭包里面, 传递过去的是, 事件发生器.
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
