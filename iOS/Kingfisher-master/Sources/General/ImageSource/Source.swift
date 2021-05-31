import Foundation

/// Represents an image setting source for Kingfisher methods.
///
/// A `Source` value indicates the way how the target image can be retrieved and cached.
///
/// - network: The target image should be got from network remotely. The associated `Resource`
///            value defines detail information like image URL and cache key.
/// - provider: The target image should be provided in a data format. Normally, it can be an image
///             from local storage or in any other encoding format (like Base64).
public enum Source {

    // 实际上, 这就是一个静态的 Int 值. 但是 Swift 里面, 使用类型表示全局数据是标准.
    public enum Identifier {

        /// The underlying value type of source identifier.
        public typealias Value = UInt
        static var current: Value = 0
        static func next() -> Value {
            current += 1
            return current
        }
    }

    // MARK: Member Cases

    // 两个 Case, 都没有挂钩具体的类型, 都是挂钩到了一层抽象上.
    
    /// The target image should be got from network remotely. The associated `Resource`
    /// value defines detail information like image URL and cache key.
    case network(Resource)
    
    /// The target image should be provided in a data format. Normally, it can be an image
    /// from local storage or in any other encoding format (like Base64).
    case provider(ImageDataProvider)

    // MARK: Getting Properties

    /// The cache key defined for this source value.
    public var cacheKey: String {
        switch self {
        case .network(let resource): return resource.cacheKey
        case .provider(let provider): return provider.cacheKey
        }
    }

    /// The URL defined for this source value.
    ///
    /// For a `.network` source, it is the `downloadURL` of associated `Resource` instance.
    /// For a `.provider` value, it is always `nil`.
    public var url: URL? {
        switch self {
        case .network(let resource): return resource.downloadURL
        case .provider(let provider): return provider.contentURL
        }
    }
}

extension Source: Hashable {
    public static func == (lhs: Source, rhs: Source) -> Bool {
        switch (lhs, rhs) {
        case (.network(let r1), .network(let r2)):
            return r1.cacheKey == r2.cacheKey && r1.downloadURL == r2.downloadURL
        case (.provider(let p1), .provider(let p2)):
            return p1.cacheKey == p2.cacheKey && p1.contentURL == p2.contentURL
        case (.provider(_), .network(_)):
            return false
        case (.network(_), .provider(_)):
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .network(let r):
            hasher.combine(r.cacheKey)
            hasher.combine(r.downloadURL)
        case .provider(let p):
            hasher.combine(p.cacheKey)
            hasher.combine(p.contentURL)
        }
    }
}

extension Source {
    var asResource: Resource? {
        guard case .network(let resource) = self else {
            return nil
        }
        return resource
    }

    var asProvider: ImageDataProvider? {
        guard case .provider(let provider) = self else {
            return nil
        }
        return provider
    }
}
