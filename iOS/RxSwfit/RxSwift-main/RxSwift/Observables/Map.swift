//
//  Map.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//


/*
    最常见的一个 Operator, 将信号的 Element 类型, 转变为 Result 类型.
    Element 是当前的 Publisher 信号中的元素类型, Result 是 Map 的结果类型.
    在实际使用的时候, Result 直接根据闭包里面的返回值类型推导出来.
 */
extension ObservableType {

    /*
     Projects each element of an observable sequence into a new form.

     - seealso: [map operator on reactivex.io](http://reactivex.io/documentation/operators/map.html)

     - parameter transform: A transform function to apply to each source element.
     - returns: An observable sequence whose elements are the result of invoking the transform function on each element of source.

     */
    public func map<Result>(_ transform: @escaping (Element) throws -> Result)
        -> Observable<Result> {
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

    /*
        Map Sink 的责任, 就是当做 Observer, 在接受到信号之后, 将数据通过 Map 进行处理之后, 直接交给下游.
        如果中途发生了意外, 调用 dispose.
     
        所有的 Sink, 在 complete, error, 都主动调用了 dispose, 这也就是为什么只要接受了这两种信号, 资源就会被回收的原因了.
     */
    func on(_ event: Event<SourceType>) {
        switch event {
        case .next(let element):
            do {
                let mappedElement = try self.transform(element)
                self.forwardOn(.next(mappedElement))
            } catch let e {
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

final private class Map<SourceType, ResultType>: Producer<ResultType> {
    
    typealias Transform = (SourceType) throws -> ResultType

    private let source: Observable<SourceType> // 信息收集, 原有的 Publisher

    private let transform: Transform // 信息收集, Map 的 Transform 到底是什么逻辑.

    init(source: Observable<SourceType>, transform: @escaping Transform) {
        self.source = source
        self.transform = transform
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = MapSink(transform: self.transform, observer: observer, cancel: cancel)
        let subscription = self.source.subscribe(sink)
        return (sink: sink, subscription: subscription)
    }
}
