//
//  Sequence.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 11/14/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

extension ObservableType {
    // MARK: of

    /**
     This method creates a new Observable instance with a variable number of elements.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - parameter elements: Elements to generate.
     - parameter scheduler: Scheduler to send elements on. If `nil`, elements are sent immediately on subscription.
     - returns: The observable sequence whose elements are pulled from the given arguments.
     */
    
    /*
        ObservableType 的 of 方法, 是新建一个对象, 这个对象是 Producer.
        ObservableSequence 所做的仅仅是信息的收集工作, 然后将数据, 传递给真正的 Sink 对象里面, 进行业务的处理.
     */
    public static func of(_ elements: Element ..., scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance) -> Observable<Element> {
        ObservableSequence(elements: elements, scheduler: scheduler)
    }
}

extension ObservableType {
    /**
     Converts an array to an observable sequence.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - returns: The observable sequence whose elements are pulled from the given enumerable sequence.
     */
    public static func from(_ array: [Element], scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance) -> Observable<Element> {
        ObservableSequence(elements: array, scheduler: scheduler)
    }

    /**
     Converts a sequence to an observable sequence.

     - seealso: [from operator on reactivex.io](http://reactivex.io/documentation/operators/from.html)

     - returns: The observable sequence whose elements are pulled from the given enumerable sequence.
     */
    public static func from<Sequence: Swift.Sequence>(_ sequence: Sequence, scheduler: ImmediateSchedulerType = CurrentThreadScheduler.instance) -> Observable<Element> where Sequence.Element == Element {
        ObservableSequence(elements: sequence, scheduler: scheduler)
    }
}

final private class ObservableSequenceSink<Sequence: Swift.Sequence, Observer: ObserverType>: Sink<Observer> where Sequence.Element == Observer.Element {
    typealias Parent = ObservableSequence<Sequence>

    private let parent: Parent

    init(parent: Parent, observer: Observer, cancel: Cancelable) {
        self.parent = parent
        super.init(observer: observer, cancel: cancel)
    }

    func run() -> Disposable {
        return self.parent.scheduler.scheduleRecursive(self.parent.elements.makeIterator()) { iterator, recurse in
            var mutableIterator = iterator
            if let next = mutableIterator.next() {
                self.forwardOn(.next(next))
                recurse(mutableIterator)
            }
            else {
                self.forwardOn(.completed)
                self.dispose()
            }
        }
    }
}

/*
    ObservableSequence 不像是 Empty, Just 那样逻辑简单, 并且, 传递过来的数据, 可能会复用.
    所以变为了一个 Producer, 将 iter sequence 的逻辑, 转交给了 Sink 对象.
 */

//
final private class ObservableSequence<Sequence: Swift.Sequence>: Producer<Sequence.Element> {
    fileprivate let elements: Sequence
    fileprivate let scheduler: ImmediateSchedulerType

    init(elements: Sequence, scheduler: ImmediateSchedulerType) {
        self.elements = elements
        self.scheduler = scheduler
    }

    override func run<Observer: ObserverType>(_ observer: Observer, cancel: Cancelable) -> (sink: Disposable, subscription: Disposable) where Observer.Element == Element {
        let sink = ObservableSequenceSink(parent: self, observer: observer, cancel: cancel)
        let subscription = sink.run()
        return (sink: sink, subscription: subscription)
    }
}
