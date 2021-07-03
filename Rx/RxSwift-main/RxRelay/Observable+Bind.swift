//
//  Observable+Bind.swift
//  RxRelay
//
//  Created by Shai Mishali on 09/04/2019.
//  Copyright © 2019 Krunoslav Zaher. All rights reserved.
//

import RxSwift

extension ObservableType {
    /**
     Creates new subscription and sends elements to publish relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter to: Target publish relays for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: PublishRelay<Element>...) -> Disposable {
        bind(to: relays)
    }

    /**
     Creates new subscription and sends elements to publish relay(s).

     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.

     - parameter to: Target publish relays for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: PublishRelay<Element?>...) -> Disposable {
        self.map { $0 as Element? }.bind(to: relays)
    }

    /**
     Creates new subscription and sends elements to publish relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter to: Target publish relays for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    /*
     Bind 仅仅是增加了一层 subscribe, 就是信号来临的时候, 执行下面的逻辑. 接受相应的值, 设置为自己的内容.
     */
    private func bind(to relays: [PublishRelay<Element>]) -> Disposable {
        subscribe { e in
            switch e {
            case let .next(element):
                relays.forEach {
                    $0.accept(element)
                }
            case let .error(error):
                rxFatalErrorInDebug("Binding error to publish relay: \(error)")
            case .completed:
                break
            }
        }
    }

    /**
     Creates new subscription and sends elements to behavior relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter to: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: BehaviorRelay<Element>...) -> Disposable {
        self.bind(to: relays)
    }

    /**
     Creates new subscription and sends elements to behavior relay(s).

     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.

     - parameter to: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: BehaviorRelay<Element?>...) -> Disposable {
        self.map { $0 as Element? }.bind(to: relays)
    }

    /**
     Creates new subscription and sends elements to behavior relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter to: Target behavior relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    private func bind(to relays: [BehaviorRelay<Element>]) -> Disposable {
        subscribe { e in
            switch e {
            case let .next(element):
                relays.forEach {
                    $0.accept(element)
                }
            case let .error(error):
                rxFatalErrorInDebug("Binding error to behavior relay: \(error)")
            case .completed:
                break
            }
        }
    }

    /**
     Creates new subscription and sends elements to replay relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter to: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: ReplayRelay<Element>...) -> Disposable {
        self.bind(to: relays)
    }

    /**
     Creates new subscription and sends elements to replay relay(s).

     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.

     - parameter to: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    public func bind(to relays: ReplayRelay<Element?>...) -> Disposable {
        self.map { $0 as Element? }.bind(to: relays)
    }

    /**
     Creates new subscription and sends elements to replay relay(s).
     In case error occurs in debug mode, `fatalError` will be raised.
     In case error occurs in release mode, `error` will be logged.
     - parameter to: Target replay relay for sequence elements.
     - returns: Disposable object that can be used to unsubscribe the observer.
     */
    private func bind(to relays: [ReplayRelay<Element>]) -> Disposable {
        subscribe { e in
            switch e {
            case let .next(element):
                relays.forEach {
                    $0.accept(element)
                }
            case let .error(error):
                rxFatalErrorInDebug("Binding error to behavior relay: \(error)")
            case .completed:
                break
            }
        }
    }
}
