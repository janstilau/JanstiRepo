//
//  Map.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    
    /**
     Projects each element of an observable sequence into a new form.
     
     - seealso: [map operator on reactivex.io](http://reactivex.io/documentation/operators/map.html)
     
     - parameter transform: A transform function to apply to each source element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source.
     
     */
    
    // Map 调用的时候, 仅仅是生成一个 Map 对象, 并没有真正的注册发生.
    public func map<Result>(_ transform: @escaping (Element) throws -> Result)
    -> Observable<Result> {
        // 当 Publisher, 使用 Map 创建一个新的 publisher 的时候.
        // 会产生一个新的对象, 将 Publisher 和 Transform 进行存储.
        // 而 Publisher 发射的信号, 如何 transform, 如何和 disposeable 进行配合使用, 是 Map 的逻辑.
        Map(source: self.asObservable(), transform: transform)
    }
}

final private class MapSink<SourceType, Observer: ObserverType>: Sink<Observer>, ObserverType {
    
    typealias Transform = (SourceType) throws -> ResultType
    typealias ResultType = Observer.Element
    typealias Element = SourceType
    
    private let transform: Transform
    
    init(transform: @escaping Transform, observer: Observer, cancel: Cancelable) {
        self.transform = transform
        super.init(observer: observer, cancel: cancel)
    }
    
    // 真正的 Map 起作用的地方, 在这里, 才是对于 Transform 真正的使用.
    // 当不能正常的 transform 的时候, 会转化对应的事件类型, 然后主动地调用 self.dispose() 函数.
    // 当能够 transform 的时候, 会主动地, 将数据传递到链条的后面.
    // 当发生错误的时候, 主动调用 dispose 进行处理.
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try self.transform(element)
                self.forwardOn(.next(mappedElement))
            }
            catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        case .error(let error):
            self.forwardOn(.error(error))
            self.dispose()
        case .completed:
            self.forwardOn(.completed)
            self.dispose()
        }
    }
}

// Publisher.map {}.map {}.map {}.map {}.subscribe {End}
// 上面的算式,  Map1, Map2   Map3   Map4
// 当最后一个 Map4 subscribe 的时候, 产生了一个 MapSink, MapSink 是一个 Observer, 里面会存储它的下一个 observer, 将事件处理变化之后, 他会发送到下一个 observer.
// 会让 Map3 进行 subscribe. 就是 self.source.subscribe(sink) 的作用.
// Map3 会产生一个 MapSink, 然后交给 Map2, 然后是 Map1.
// 最终 Map1 最调用的 Publisher 的 subscibe.
// 所以到最后, 由最后一个 subscribe, 形成了最终的 Publisher --> MapSink --> MapSink --> MapSink --> MapSink --> End 的这样一个链式的结构.
// Map Sink 并不是一个 Publisher, 他仅仅是事件的中转者.
// 当, 最后的一个 disposed 对象调用 dispose 的时候, 其实会链式从后向前调用 dispose 方法的.
final private class Map<SourceType, ResultType>: Producer<ResultType> {
    
    typealias Transform = (SourceType) throws -> ResultType
    
    private let source: Observable<SourceType> // 主动存储, 原有的 publisher.
    
    private let transform: Transform // 主动的存储, 转换闭包.
    
    init(source: Observable<SourceType>, transform: @escaping Transform) {
        self.source = source
        self.transform = transform
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        // MapSink 里面, cancel 是外界生成的.
        let sink = MapSink(transform: self.transform,
                           observer: observer,
                           cancel: cancel)
        // 这里, source.subscribe 产生了一个 dispose 的, 传递过来的, cancel 也是一个 dispose.
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
