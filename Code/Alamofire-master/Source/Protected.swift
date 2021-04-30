import Foundation

// 一个协议, 一群 primitive 能力.
private protocol Lock {
    func lock()
    func unlock()
}

// 在 primitive 的能力之上, 可以有模板方法. 这些模板方法, 有着固定的流程.
// 实现类重写 primitive 方法, 可以自定义操作.
/*
 Swift 里面, 这种将闭包作为参数进行操作的方法, 非常非常多.
 */
extension Lock {
    /// Executes a closure returning a value while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    ///
    /// - Returns:           The value the closure generated.
    func around<T>(_ closure: () -> T) -> T {
        lock(); defer { unlock() }
        return closure()
    }

    /// Execute a closure while acquiring the lock.
    ///
    /// - Parameter closure: The closure to run.
    func around(_ closure: () -> Void) {
        lock(); defer { unlock() }
        closure()
    }
}

#if os(Linux)
/// A `pthread_mutex_t` wrapper.

// 封装了 Pthread_mutex lock
// 这个类, 是资源管理类, 要在 Init, Deinit 方法里面, 做相应的资源的管理工作.
final class MutexLock: Lock {
    private var mutex: UnsafeMutablePointer<pthread_mutex_t>

    init() {
        mutex = .allocate(capacity: 1)

        var attr = pthread_mutexattr_t()
        pthread_mutexattr_init(&attr)
        pthread_mutexattr_settype(&attr, .init(PTHREAD_MUTEX_ERRORCHECK))

        let error = pthread_mutex_init(mutex, &attr)
        precondition(error == 0, "Failed to create pthread_mutex")
    }

    deinit {
        let error = pthread_mutex_destroy(mutex)
        precondition(error == 0, "Failed to destroy pthread_mutex")
    }

    // 对于协议的实现, 就是利用 C 风格的 Mutex 进行的实现.
    fileprivate func lock() {
        let error = pthread_mutex_lock(mutex)
        precondition(error == 0, "Failed to lock pthread_mutex")
    }

    // 对于协议的实现, 就是利用 C 风格的 Mutex 进行的实现.
    fileprivate func unlock() {
        let error = pthread_mutex_unlock(mutex)
        precondition(error == 0, "Failed to unlock pthread_mutex")
    }
}
#endif

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
/// An `os_unfair_lock` wrapper.
final class UnfairLock: Lock {
    private let unfairLock: os_unfair_lock_t

    init() {
        unfairLock = .allocate(capacity: 1)
        unfairLock.initialize(to: os_unfair_lock())
    }

    deinit {
        unfairLock.deinitialize(count: 1)
        unfairLock.deallocate()
    }

    fileprivate func lock() {
        os_unfair_lock_lock(unfairLock)
    }

    fileprivate func unlock() {
        os_unfair_lock_unlock(unfairLock)
    }
}
#endif

/// A thread-safe wrapper around a value.
/*
 propertyWrapper 这个语法的本质, 其实就是定义一个类, 将 get set 方法的一些其他操作, 封装到这个类当中.
 一般来说, 这个类都是泛型类. 因为, 类里面封装的是通用方法, 定义属性的时候, 来确定类型.
 */
@propertyWrapper
@dynamicMemberLookup
final class Protected<T> {
    #if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
    private let lock = UnfairLock()
    #elseif os(Linux)
    private let lock = MutexLock()
    #endif
    private var value: T

    init(_ value: T) {
        self.value = value
    }

    /// The contained value. Unsafe for anything more than direct read or write.
    // PropertyWrapper 的固定的方法, 就是 wrappedValue, 它的类型, 和属性的类型是绑定在一起的. 这样在属性定义的时候, 才能做类型的推导.
    var wrappedValue: T {
        get { lock.around { value } }
        set { lock.around { value = newValue } }
    }

    // 一个很特殊的值, $name 可以取到这个值.
    // 所以, 其实每一次用 propertyWrapper 的时候, 类型信息都是编译器固定了的. 这样, 这里返回一个泛型<T>对象, 才是一个类型安全的对象.
    var projectedValue: Protected<T> { self }

    init(wrappedValue: T) {
        value = wrappedValue
    }

    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The return value of the closure passed.
    /*
     通用方法, 经常定义成为这样的, 参数一个 () -> T 的闭包.
     这种闭包最大的好处就是, 有着很强的操作性. 在类的内部, 可以编写接收一个功能点的闭包, 然后在这个闭包前后增加类内相关的逻辑, 然后将这些逻辑, 组织成为一个 () -> 的闭包, 传到通用方法中.
     Validate, response 这几个通用方法, 都是这样的设计思路.
     */
    func read<U>(_ closure: (T) -> U) -> U {
        lock.around { closure(self.value) }
    }

    /// Synchronously modify the protected value.
    ///
    /// - Parameter  closure: The closure to execute.
    ///
    /// - Returns:           The modified value.
    // Write 函数, 就是将自己的成员变量传入到对应的 closure 之上.
    @discardableResult
    func write<U>(_ closure: (inout T) -> U) -> U {
        lock.around { closure(&self.value) }
    }

    // keyPath 是一个通用的行为, 在这里, 为这种通用行为, 也进行了支持.
    subscript<Property>(dynamicMember keyPath: WritableKeyPath<T, Property>) -> Property {
        get { lock.around { value[keyPath: keyPath] } }
        set { lock.around { value[keyPath: keyPath] = newValue } }
    }
}

extension Protected where T: RangeReplaceableCollection {
    /// Adds a new element to the end of this protected collection.
    ///
    /// - Parameter newElement: The `Element` to append.
    func append(_ newElement: T.Element) {
        write {
            (ward: inout T) in
            ward.append(newElement)
        }
    }

    /// Adds the elements of a sequence to the end of this protected collection.
    ///
    /// - Parameter newElements: The `Sequence` to append.
    func append<S: Sequence>(contentsOf newElements: S) where S.Element == T.Element {
        write {
            (ward: inout T) in
            ward.append(contentsOf: newElements)
        }
    }

    /// Add the elements of a collection to the end of the protected collection.
    ///
    /// - Parameter newElements: The `Collection` to append.
    func append<C: Collection>(contentsOf newElements: C) where C.Element == T.Element {
        write {
            (ward: inout T) in
            ward.append(contentsOf: newElements)
        }
    }
}

extension Protected where T == Data? {
    /// Adds the contents of a `Data` value to the end of the protected `Data`.
    ///
    /// - Parameter data: The `Data` to be appended.
    func append(_ data: Data) {
        write {
            (ward: inout T) in
            ward?.append(data)
        }
    }
}

extension Protected where T == Request.MutableState {
    /// Attempts to transition to the passed `State`.
    ///
    /// - Parameter state: The `State` to attempt transition to.
    ///
    /// - Returns:         Whether the transition occurred.
    func attemptToTransitionTo(_ state: Request.State) -> Bool {
        lock.around {
            guard value.state.canTransitionTo(state) else { return false }

            value.state = state

            return true
        }
    }

    /// Perform a closure while locked with the provided `Request.State`.
    ///
    /// - Parameter perform: The closure to perform while locked.
    func withState(perform: (Request.State) -> Void) {
        lock.around { perform(value.state) }
    }
}
