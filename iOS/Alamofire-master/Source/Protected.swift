import Foundation

private protocol Lock {
    func lock()
    func unlock()
}

/*
    两个函数, 具有同样的逻辑.
    根据传入的参数是否有返回值, 调用不同的函数. 这是编译器完成的.
 
    这个使用的非常广.
 */
extension Lock {
    func around<T>(_ closure: () -> T) -> T {
        lock();
        defer { unlock() }
        return closure()
    }
    
    func around(_ closure: () -> Void) {
        lock();
        defer { unlock() }
        closure()
    }
}


/*
    在不同的平台上, 使用不同的锁, 完成 lock 的功能.
 */

#if os(Linux)
/// A `pthread_mutex_t` wrapper.
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
    
    fileprivate func lock() {
        let error = pthread_mutex_lock(mutex)
        precondition(error == 0, "Failed to lock pthread_mutex")
    }
    
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



// A thread-safe wrapper around a value.

/*
    这个属性包装类, 主要的工作, 就是对于自己存储的 value 的任务 get, set, 都在 Lock 的环境下.
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
    
    // 最重要的值的 get, set 方法, 会被 lock 锁定, 保证了线程安全.
    /// The contained value. Unsafe for anything more than direct read or write.
    var wrappedValue: T {
        get { lock.around { value } }
        set { lock.around { value = newValue } }
    }
    
    // projectedValue 把自己暴露出去.
    var projectedValue: Protected<T> { self }
    
    init(wrappedValue: T) {
        value = wrappedValue
    }
    
    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The return value of the closure passed.
    func read<U>(_ closure: (T) -> U) -> U {
        lock.around { closure(self.value) }
    }
    
    /// Synchronously modify the protected value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The modified value.
    @discardableResult
    func write<U>(_ closure: (inout T) -> U) -> U {
        lock.around { closure(&self.value) }
    }
    
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
        write { (ward: inout T) in
            ward.append(newElement)
        }
    }
    
    /// Adds the elements of a sequence to the end of this protected collection.
    ///
    /// - Parameter newElements: The `Sequence` to append.
    func append<S: Sequence>(contentsOf newElements: S) where S.Element == T.Element {
        write { (ward: inout T) in
            ward.append(contentsOf: newElements)
        }
    }
    
    /// Add the elements of a collection to the end of the protected collection.
    ///
    /// - Parameter newElements: The `Collection` to append.
    func append<C: Collection>(contentsOf newElements: C) where C.Element == T.Element {
        write { (ward: inout T) in
            ward.append(contentsOf: newElements)
        }
    }
}

extension Protected where T == Data? {
    /// Adds the contents of a `Data` value to the end of the protected `Data`.
    ///
    /// - Parameter data: The `Data` to be appended.
    func append(_ data: Data) {
        write { (ward: inout T) in
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
