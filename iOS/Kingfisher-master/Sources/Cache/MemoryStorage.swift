import Foundation

/// Represents a set of conception related to storage which stores a certain type of value in memory.
/// This is a namespace for the memory storage types. A `Backend` with a certain `Config` will be used to describe the
/// storage. See these composed types for more information.

// 这里, MemoryStorage 是一个命名空间, 本身这个 Enum 里面, 并没有任何的 case 存在.

// 其实, 这个文件里面, 就是定义了三个类.
// 只不过这三个类, 都在 MemoryStorage 之下. 所以, 没有定义在一起.
// 整体上说,  MemoryCache 的逻辑还是比较简单的. 
public enum MemoryStorage {
    
    /// Represents a storage which stores a certain type of value in memory. It provides fast access,
    /// but limited storing size. The stored value type needs to conform to `CacheCostCalculable`,
    /// and its `cacheCost` will be used to determine the cost of size for the cache item.
    ///
    /// You can config a `MemoryStorage.Backend` in its initializer by passing a `MemoryStorage.Config` value.
    /// or modifying the `config` property after it being created. The backend of `MemoryStorage` has
    /// upper limitation on cost size in memory and item count. All items in the storage has an expiration
    /// date. When retrieved, if the target item is already expired, it will be recognized as it does not
    /// exist in the storage. The `MemoryStorage` also contains a scheduled self clean task, to evict expired
    /// items from memory.
    public class Backend<T: CacheCostCalculable> {
        // 实际上, 进行存储就是使用了 NSCache 类.
        // 至于 NSCache 类如何实现 totalCost, 以及 limitCount, 这是 NSCache 类内部的逻辑.
        let storage = NSCache<NSString, StorageObject<T>>()
        
        // Keys trackes the objects once inside the storage. For object removing triggered by user, the corresponding
        // key would be also removed. However, for the object removing triggered by cache rule/policy of system, the
        // key will be remained there until next `removeExpired` happens.
        //
        // Breaking the strict tracking could save additional locking behaviors.
        // See https://github.com/onevcat/Kingfisher/issues/1233
        var keys = Set<String>()
        
        // 这里, 既然每次 init 方法, 都会让 timer 生成, 为什么这个值还是一个 optinal 值.
        private var cleanTimer: Timer? = nil
        private let lock = NSLock()
        
        /// The config used in this storage. It is a value you can set and
        /// use to config the storage in air.
        public var config: Config {
            didSet {
                storage.totalCostLimit = config.totalCostLimit
                storage.countLimit = config.countLimit
            }
        }
        
        /// Creates a `MemoryStorage` with a given `config`.
        ///
        /// - Parameter config: The config used to create the storage. It determines the max size limitation,
        ///                     default expiration setting and more.
        public init(config: Config) {
            self.config = config
            storage.totalCostLimit = config.totalCostLimit
            storage.countLimit = config.countLimit
            
            /*
                Timer 的 Target, Action 和 Block 的形式, 其实没有太大的区别.
                虽然, 在内部一个是使用了运行时, 一个是存储闭包, 但是作为使用者来说, 都能够达到同样的目的.
                同时, 只要注意到了内存问题, weak self 的捕获和 target 使用 proxy 都没有问题.
                所以, 今后多使用 Block 的形式, 是一个好的选择.
             */
            cleanTimer = .scheduledTimer(withTimeInterval: config.cleanInterval,
                                         repeats: true)
            { [weak self] _ in
                guard let self = self else { return }
                self.removeExpired()
            }
        }
        
        /// Removes the expired values from the storage.
        // 每次定时器的触发, 都是进行一次过期数据的筛选.
        public func removeExpired() {
            // 每次都加锁.
            lock.lock()
            defer { lock.unlock() }
            
            // 里面实现的逻辑也很简单, 就是判断每个存储的数据, 是否已经过期了.
            // 在实现业务的时候, 容器里面, 一般都是存储一个 Item. 这个 Item 处理最终需要的那个业务数据部分之外, 也会存储相关的逻辑控制部分.
            // 将逻辑, 移交到这个逻辑控制部分, 会让代码变得简单.
            for key in keys {
                let nsKey = key as NSString
                guard let object = storage.object(forKey: nsKey) else {
                    // This could happen if the object is moved by cache `totalCostLimit` or `countLimit` rule.
                    // We didn't remove the key yet until now, since we do not want to introduce additional lock.
                    // See https://github.com/onevcat/Kingfisher/issues/1233
                    keys.remove(key)
                    continue
                }
                if object.estimatedExpiration.isPast {
                    storage.removeObject(forKey: nsKey)
                    keys.remove(key)
                }
            }
        }
        
        /// Stores a value to the storage under the specified key and expiration policy.
        /// - Parameters:
        ///   - value: The value to be stored.
        ///   - key: The key to which the `value` will be stored.
        ///   - expiration: The expiration policy used by this store action.
        /// - Throws: No error will
        public func store(
            value: T,
            forKey key: String,
            expiration: StorageExpiration? = nil)
        {
            storeNoThrow(value: value, forKey: key, expiration: expiration)
        }
        
        // The no throw version for storing value in cache. Kingfisher knows the detail so it
        // could use this version to make syntax simpler internally.
        func storeNoThrow(
            value: T,
            forKey key: String,
            expiration: StorageExpiration? = nil)
        {
            lock.lock()
            defer { lock.unlock() }
            
            let expiration = expiration ?? config.expiration
            guard !expiration.isExpired else { return }
            
            
            // 这里不太明白, 为什么 keys 会单独独立出来了.
            let object = StorageObject(value, key: key, expiration: expiration)
            storage.setObject(object, forKey: key as NSString, cost: value.cacheCost)
            keys.insert(key)
        }
        
        /// Gets a value from the storage.
        ///
        /// - Parameters:
        ///   - key: The cache key of value.
        ///   - extendingExpiration: The expiration policy used by this getting action.
        /// - Returns: The value under `key` if it is valid and found in the storage. Otherwise, `nil`.
        public func value(forKey key: String, extendingExpiration: ExpirationExtending = .cacheTime) -> T? {
            guard let object = storage.object(forKey: key as NSString) else {
                return nil
            }
            if object.expired {
                return nil
            }
            // 每次读取数据的时候, 都进行过期时间的刷新工作.
            object.extendExpiration(extendingExpiration)
            return object.value
        }
        
        /// Whether there is valid cached data under a given key.
        /// - Parameter key: The cache key of value.
        /// - Returns: If there is valid data under the key, `true`. Otherwise, `false`.
        public func isCached(forKey key: String) -> Bool {
            guard let _ = value(forKey: key, extendingExpiration: .none) else {
                return false
            }
            return true
        }
        
        /// Removes a value from a specified key.
        /// - Parameter key: The cache key of value.
        public func remove(forKey key: String) {
            lock.lock()
            defer { lock.unlock() }
            storage.removeObject(forKey: key as NSString)
            keys.remove(key)
        }
        
        /// Removes all values in this storage.
        public func removeAll() {
            lock.lock()
            defer { lock.unlock() }
            storage.removeAllObjects()
            keys.removeAll()
        }
    }
}


// 在 OC 的时候, 会有各种 Config 类的定义.
// 在 Swfit 里面, 各种定义都是在类内部, 或者像这里一样, 使用 namespace 进行包裹.
// Config 类的逻辑, 其实很简单, 就是一堆值的集合.
// 在逻辑代码里面, 根据这些 config 的值, 进行逻辑的控制.

extension MemoryStorage {
    /// Represents the config used in a `MemoryStorage`.
    public struct Config {
        
        /// Total cost limit of the storage in bytes.
        public var totalCostLimit: Int
        
        /// The item count limit of the memory storage.
        public var countLimit: Int = .max
        
        /// The `StorageExpiration` used in this memory storage. Default is `.seconds(300)`,
        /// means that the memory cache would expire in 5 minutes.
        public var expiration: StorageExpiration = .seconds(300)
        
        /// The time interval between the storage do clean work for swiping expired items.
        public let cleanInterval: TimeInterval
        
        /// Creates a config from a given `totalCostLimit` value.
        ///
        /// - Parameters:
        ///   - totalCostLimit: Total cost limit of the storage in bytes.
        ///   - cleanInterval: The time interval between the storage do clean work for swiping expired items.
        ///                    Default is 120, means the auto eviction happens once per two minutes.
        ///
        /// - Note:
        /// Other members of `MemoryStorage.Config` will use their default values when created.
        public init(totalCostLimit: Int, cleanInterval: TimeInterval = 120) {
            self.totalCostLimit = totalCostLimit
            self.cleanInterval = cleanInterval
        }
    }
}

extension MemoryStorage {
    
    // 存储的数据.
    // 对于内存里面的数据来说, T 的要求是, 可以判断出它的过期时间.
    // 没有序列化的要求.
    class StorageObject<T> {
        let value: T
        let expiration: StorageExpiration
        let key: String
        
        private(set) var estimatedExpiration: Date
        
        init(_ value: T, key: String, expiration: StorageExpiration) {
            self.value = value
            self.key = key
            self.expiration = expiration
            self.estimatedExpiration = expiration.estimatedExpirationSinceNow
        }
        
        // 每当 Image 被 touch 的时候, 使用这个方法, 重新刷新内存里面图的过期时间.
        func extendExpiration(_ extendingExpiration: ExpirationExtending = .cacheTime) {
            switch extendingExpiration {
            case .none:
                return
            case .cacheTime:
                self.estimatedExpiration = expiration.estimatedExpirationSinceNow
            case .expirationTime(let expirationTime):
                self.estimatedExpiration = expirationTime.estimatedExpirationSinceNow
            }
        }
        
        var expired: Bool {
            return estimatedExpiration.isPast
        }
    }
}
