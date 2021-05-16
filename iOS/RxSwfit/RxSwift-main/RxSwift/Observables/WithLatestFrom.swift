//
//  WithLatestFrom.swift
//  RxSwift
//
//  Created by Yury Korolev on 10/19/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/*
    First 的信号触发后, 会将 First 的 Value 值和 Second 之前触发的值合并到一次, 使用 resultSelector 转化成为新的值, 移交到后续的节点.
    Second 的信号, 仅仅是被 Sink 接受后进行存储. 在 First 的信号触发之后, 和 First 的值当做后续节点的原材料.
    Second 的信号, 不会触发整体的事件流转.
 
 */


extension ObservableType {

    /**
     Merges two observable sequences into one observable sequence by combining each element from self with the latest element from the second source, if any.

     - seealso: [combineLatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)
     - note: Elements emitted by self before the second source has emitted any values will be omitted.

     - parameter second: Second observable source.
     - parameter resultSelector: Function to invoke for each element from the self combined with the latest element from the second source, if any.
     - returns: An observable sequence containing the result of combining each element of the self  with the latest element from the second source, if any, using the specified result selector function.
     */
    public func withLatestFrom<Source: ObservableConvertibleType, ResultType>(_ second: Source, resultSelector: @escaping (Element, Source.Element) throws -> ResultType) -> Observable<ResultType> {
        WithLatestFrom(first: self.asObservable(), second: second.asObservable(), resultSelector: resultSelector)
    }

    /**
     Merges two observable sequences into one observable sequence by using latest element from the second sequence every time when `self` emits an element.

     - seealso: [combineLatest operator on reactivex.io](http://reactivex.io/documentation/operators/combinelatest.html)
     - note: Elements emitted by self before the second source has emitted any values will be omitted.

     - parameter second: Second observable source.
     - returns: An observable sequence containing the result of combining each element of the self  with the latest element from the second source, if any, using the specified result selector function.
     */
    /*
     将 resultSelector 固定为 $1, 那么 self 就是作为 second 的触发器了.
     */
    public func withLatestFrom<Source: ObservableConvertibleType>(_ second: Source) -> Observable<Source.Element> {
        WithLatestFrom(first: self.asObservable(), second: second.asObservable(), resultSelector: { $1 })
    }
}

final private class WithLatestFromSink<FirstType, SecondType, Observer: ObserverType>
    : Sink<Observer>
    , ObserverType
    , LockOwnerType
    , SynchronizedOnType {
    typealias ResultType = Observer.Element
    typealias Parent = WithLatestFrom<FirstType, SecondType, ResultType>
    typealias Element = FirstType
    
    private let parent: Parent
    
    fileprivate var lock = RecursiveLock()
    fileprivate var latest: SecondType? // 这是 Second 的类型.

    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        
        super.init(observer: observer, cancel: cancel)
    }
    
    func run() -> Disposable {
        let sndSubscription = SingleAssignmentDisposable()
        let sndO = WithLatestFromSecond(parent: self, disposable: sndSubscription)
        
        sndSubscription.setDisposable(self.parent.second.subscribe(sndO))
        /*
         First 会触发 Sink 的操作.
         */
        let fstSubscription = self.parent.first.subscribe(self)

        return Disposables.create(fstSubscription, sndSubscription)
    }

    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }

    /*
     Sink 的 On 方法里面,
     */
    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case let .next(value):
            guard let latest = self.latest else { return }
            do {
                let res = try self.parent.resultSelector(value, latest)
                
                self.forwardOn(.next(res))
            } catch let e {
                self.forwardOn(.error(e))
                self.dispose()
            }
        case .completed:
            self.forwardOn(.completed)
            self.dispose()
        case let .error(error):
            self.forwardOn(.error(error))
            self.dispose()
        }
    }
}

final private class WithLatestFromSecond<FirstType, SecondType, Observer: ObserverType>
    : ObserverType
    , LockOwnerType
    , SynchronizedOnType {
    
    typealias ResultType = Observer.Element
    typealias Parent = WithLatestFromSink<FirstType, SecondType, Observer>
    typealias Element = SecondType
    
    private let parent: Parent
    private let disposable: Disposable

    var lock: RecursiveLock {
        self.parent.lock
    }

    init(parent: Parent, disposable: Disposable) {
        self.parent = parent
        self.disposable = disposable
    }

    /*
     Second 的信号, 会在这里进行一次存储.
     First 触发的时候, 判断一下 latest 有没有值.
     */
    func on(_ event: Event<Element>) {
        self.synchronizedOn(event)
    }

    func synchronized_on(_ event: Event<Element>) {
        switch event {
        case let .next(value):
            self.parent.latest = value
        case .completed:
            self.disposable.dispose()
        case let .error(error):
            self.parent.forwardOn(.error(error))
            self.parent.dispose()
        }
    }
}

final private class WithLatestFrom<FirstType, SecondType, ResultType>: Producer<ResultType> {
    typealias ResultSelector = (FirstType, SecondType) throws -> ResultType
    
    fileprivate let first: Observable<FirstType> // Source
    fileprivate let second: Observable<SecondType>
    fileprivate let resultSelector: ResultSelector

    init(first: Observable<FirstType>, second: Observable<SecondType>, resultSelector: @escaping ResultSelector) {
        self.first = first
        self.second = second
        self.resultSelector = resultSelector
    }
    
    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == ResultType {
        let sink = WithLatestFromSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}
