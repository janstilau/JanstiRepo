//
//  AnonymousDisposable.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/15/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

/// Represents an Action-based disposable.
///
/// When dispose method is called, disposal action will be dereferenced.

/*
    相比较于 Any 存储一个 Block 来泛化操作之外, Disposable 还有一个需求, 就是每个 Block 其实只能被调用一次.
    所以在里面, 有一个 disposed 的 AtomicInt 存在, 作为只调用一次的判断.
 */
private final class AnonymousDisposable : DisposeBase, Cancelable {
    
    public typealias DisposeAction = () -> Void

    private let disposed = AtomicInt(0)
    private var disposeAction: DisposeAction?

    /// - returns: Was resource disposed.
    public var isDisposed: Bool {
        isFlagSet(self.disposed, 1)
    }

    /// Constructs a new disposable with the given action used for disposal.
    ///
    /// - parameter disposeAction: Disposal action which will be run upon calling `dispose`.
    private init(_ disposeAction: @escaping DisposeAction) {
        self.disposeAction = disposeAction
        super.init()
    }

    // Non-deprecated version of the constructor, used by `Disposables.create(with:)`
    fileprivate init(disposeAction: @escaping DisposeAction) {
        self.disposeAction = disposeAction
        super.init()
    }

    /// Calls the disposal action if and only if the current instance hasn't been disposed yet.
    ///
    /// After invoking disposal action, disposal action will be dereferenced.
    // fetchOr 本身会修改自己的值, 并且返回原来的值.
    // 这里, 保证了 self.disposeAction 只会被调用一次.
    fileprivate func dispose() {
        if fetchOr(self.disposed, 1) == 0 {
            if let action = self.disposeAction {
                self.disposeAction = nil
                action()
            }
        }
    }
}

extension Disposables {
    public static func create(with dispose: @escaping () -> Void) -> Cancelable {
        AnonymousDisposable(disposeAction: dispose)
    }

}
