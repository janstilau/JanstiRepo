import Foundation

/// Represents an image resource at a certain url and a given cache key.
/// Kingfisher will use a `Resource` to download a resource from network and cache it with the cache key when
/// using `Source.network` as its image setting source.
/*
    downloadURL 提供图片的 URL 进行数据的下载.
    cacheKey 提供一个缓存的索引.
 
    本来其实就是一个 URL, 并且 URL 也能够当做 Cache 的值, 在 SDWebImage 里面, 也确实是 Url 的 MD5 当做的 CacheKey.
    但是, 这里 Swfit 还是做了一层抽象. 在真正编码的时候, 是使用这层抽象.
    同时, 作为最原始的 URL, 实现了这层抽象.
 
    这其实是有很大的好处的. 一个抽象类, 本身就能承担很多的业务代码. 并且, 它也提供了一个 URL, 从这层意义上来说, 这个抽象, 不是 Url 的封装, 而是扩展了.
    并且, 这里提供了自定义 Resource 的 ImageResource, 可以认为是更好地进行 Mock 的方式.
 */
public protocol Resource {
    
    /// The key used in cache.
    var cacheKey: String { get }
    
    /// The target image URL.
    var downloadURL: URL { get }
}

// 作为抽象, 就是能够添加方法的类型.
// 这里, 提供了向 Source 类转化的逻辑.
// 并且, 实现了其中的转化逻辑.
extension Resource {

    /// Converts `self` to a valid `Source` based on its `downloadURL` scheme. A `.provider` with
    /// `LocalFileImageDataProvider` associated will be returned if the URL points to a local file. Otherwise,
    /// `.network` is returned.
    public func convertToSource(overrideCacheKey: String? = nil) -> Source {
        return downloadURL.isFileURL ?
            .provider(LocalFileImageDataProvider(fileURL: downloadURL,
                                                 cacheKey: overrideCacheKey ?? cacheKey)) :
            .network(ImageResource(downloadURL: downloadURL,
                                   cacheKey: overrideCacheKey ?? cacheKey))
    }
}

/// ImageResource is a simple combination of `downloadURL` and `cacheKey`.
/// When passed to image view set methods, Kingfisher will try to download the target
/// image from the `downloadURL`, and then store it with the `cacheKey` as the key in cache.
public struct ImageResource: Resource {

    // MARK: - Initializers

    /// Creates an image resource.
    ///
    /// - Parameters:
    ///   - downloadURL: The target image URL from where the image can be downloaded.
    ///   - cacheKey: The cache key. If `nil`, Kingfisher will use the `absoluteString` of `downloadURL` as the key.
    ///               Default is `nil`.
    public init(downloadURL: URL, cacheKey: String? = nil) {
        self.downloadURL = downloadURL
        self.cacheKey = cacheKey ?? downloadURL.absoluteString
    }

    // MARK: Protocol Conforming
    
    /// The key used in cache.
    public let cacheKey: String

    /// The target image URL.
    public let downloadURL: URL
}

/// URL conforms to `Resource` in Kingfisher.
/// The `absoluteString` of this URL is used as `cacheKey`. And the URL itself will be used as `downloadURL`.
/// If you need customize the url and/or cache key, use `ImageResource` instead.

// Swift 里面, 定义一个抽象接口, 一定会让原始的最直观的类型, 去实现这个接口.
// 这样, 在使用的时候, 不会因为使用了一个抽象类型, 带来转化的代价.
extension URL: Resource {
    public var cacheKey: String { return absoluteString }
    public var downloadURL: URL { return self }
}
