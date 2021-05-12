//
//  DisposeBag.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 3/25/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

// 将自身, 添加到 Bag 中, 在 Bag 消亡的时候, 进行 dispose 的操作.
extension Disposable {
    /// Adds `self` to `bag`
    ///
    /// - parameter bag: `DisposeBag` to add `self` to.
    public func disposed(by bag: DisposeBag) {
        bag.insert(self)
    }
}

/**
Thread safe bag that disposes added disposables on `deinit`.

This returns ARC (RAII) like resource management to `RxSwift`.

In case contained disposables need to be disposed, just put a different dispose bag
or create a new one in its place.

    self.existingDisposeBag = DisposeBag()

In case explicit disposal is necessary, there is also `CompositeDisposable`.
*/
public final class DisposeBag: DisposeBase {
    
    private var lock = SpinLock()
    
    // state
    private var disposables = [Disposable]()
    private var isDisposed = false
    
    /// Constructs new empty dispose bag.
    public override init() {
        super.init()
    }

    /// Adds `disposable` to be disposed when dispose bag is being deinited.
    ///
    /// - parameter disposable: Disposable to add.
    public func insert(_ disposable: Disposable) {
        self._insert(disposable)?.dispose()
    }
    
    // 如果, 当前 Bag 已经释放了, 那么就直接释放添加的元素.
    // 否则返回 nil
    // 这里感觉逻辑复杂了, 还专门返回了一个对象.
    private func _insert(_ disposable: Disposable) -> Disposable? {
        self.lock.performLocked {
            if self.isDisposed {
                return disposable
            }

            self.disposables.append(disposable)

            return nil
        }
    }

    /// This is internal on purpose, take a look at `CompositeDisposable` instead.\
    // Bag 的 dispose, 就是每一个 Item 调用 dispose
    private func dispose() {
        let oldDisposables = self._dispose()

        for disposable in oldDisposables {
            disposable.dispose()
        }
    }

    // 私有的方法, 有线程考虑.
    private func _dispose() -> [Disposable] {
        self.lock.performLocked {
            let disposables = self.disposables
            
            self.disposables.removeAll(keepingCapacity: false)
            self.isDisposed = true
            
            return disposables
        }
    }
    
    // 在析构的时候, 调用了 dispose.
    // 也就是在析构的时候, 调用资源释放的方法.
    // iOS 里面, 内存资源都让 arc 接管了. 这里, 之所以出现了这样的一个类, 是因为资源的释放, 在 RXSwfit 里面, 是使用了一个特殊的接口进行管理的.
    // 而这个接口的主动调用, 就需要写一个 RAII 类进行管理了.
    deinit {
        self.dispose()
    }
}

extension DisposeBag {
    /// Convenience init allows a list of disposables to be gathered for disposal.
    public convenience init(disposing disposables: Disposable...) {
        self.init()
        self.disposables += disposables
    }

    /// Convenience init which utilizes a function builder to let you pass in a list of
    /// disposables to make a DisposeBag of.
    public convenience init(@DisposableBuilder builder: () -> [Disposable]) {
      self.init(disposing: builder())
    }

    /// Convenience init allows an array of disposables to be gathered for disposal.
    public convenience init(disposing disposables: [Disposable]) {
        self.init()
        self.disposables += disposables
    }

    /// Convenience function allows a list of disposables to be gathered for disposal.
    public func insert(_ disposables: Disposable...) {
        self.insert(disposables)
    }

    /// Convenience function allows a list of disposables to be gathered for disposal.
    public func insert(@DisposableBuilder builder: () -> [Disposable]) {
        self.insert(builder())
    }

    /// Convenience function allows an array of disposables to be gathered for disposal.
    public func insert(_ disposables: [Disposable]) {
        self.lock.performLocked {
            if self.isDisposed {
                disposables.forEach { $0.dispose() }
            } else {
                self.disposables += disposables
            }
        }
    }

    /// A function builder accepting a list of Disposables and returning them as an array.
    #if swift(>=5.4)
    @resultBuilder
    public struct DisposableBuilder {
      public static func buildBlock(_ disposables: Disposable...) -> [Disposable] {
        return disposables
      }
    }
    #else
    @_functionBuilder
    public struct DisposableBuilder {
      public static func buildBlock(_ disposables: Disposable...) -> [Disposable] {
        return disposables
      }
    }
    #endif
    
}
