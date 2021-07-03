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

    // Dispose 可能会被多次调用的, 比如添加到一个 CompositeDisposable 中.
    // Schedule 里面, 定时器触发真正的 Action, CompositeDisposable 里面添加了 timer 的 disposable, Action 的 disposable.
    // 然后将 CompositeDisposable 返回. 外界调用 CompositeDisposable 的 dispose, 会触发里面的所有 disposable.
    // timer 触发的时候, 本身就自己触发了 dispose 方法了, 所以, 内部记录下自己已经触发的状态, 并且在触发之后, 主动释放 disposeAction. 这样, 就算以后再次被触发, 也不会有实际的操作, 不会有资源的泄漏.
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
