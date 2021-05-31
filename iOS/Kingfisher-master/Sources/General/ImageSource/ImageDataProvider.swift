import Foundation

/// Represents a data provider to provide image data to Kingfisher when setting with
/// `Source.provider` source. Compared to `Source.network` member, it gives a chance
/// to load some image data in your own way, as long as you can provide the data
/// representation for the image.
public protocol ImageDataProvider {
    
    /// The key used in cache.
    var cacheKey: String { get }
    
    /// Provides the data which represents image. Kingfisher uses the data you pass in the
    /// handler to process images and caches it for later use.
    ///
    /// - Parameter handler: The handler you should call when you prepared your data.
    ///                      If the data is loaded successfully, call the handler with
    ///                      a `.success` with the data associated. Otherwise, call it
    ///                      with a `.failure` and pass the error.
    ///
    /// - Note:
    /// If the `handler` is called with a `.failure` with error, a `dataProviderError` of
    /// `ImageSettingErrorReason` will be finally thrown out to you as the `KingfisherError`
    /// from the framework.
    
    /*
        要思考一下, 为什么一个协议里面, 要用这种方式来定义接口.
        最主要的原因, 就是异步.
        常规的接口, 要么是通知事件发生, 要么是获取同步获取数据.
        但是获取资源这件事, 本身可能是耗时操作, 也就是说, ImageDataProvider 本身可能会有异步的资源获取的方式.
        回忆一下, RESULT 这个类, 本身就是异步操作下, 用来表示结果的一个类, 是由社区发展推动到的苹果而出的 Api;
        可以学习一下这种方式, data 表明, 这还是 imageDataProvider 协议的一个接口, 是需要实现类实现的.
        而传入一个闭包, 这闭包, 是回调的概念, 是外界想要实现者在完成自己逻辑后主动调用的.
        闭包的结果, 不在是 bool, value 这种形式, 而是使用 Swfit 更加富有表达含义的 Result 这种结构.
     */
    func data(handler: @escaping (Result<Data, Error>) -> Void)

    /// The content URL represents this provider, if exists.
    var contentURL: URL? { get }
}

public extension ImageDataProvider {
    var contentURL: URL? { return nil }
    func convertToSource() -> Source {
        .provider(self)
    }
}


/*
    虽然, 我们使用的时候, 一般也就会使用 LocalFileImageDataProvider.
    但是, 抽象出协议, 让我们使用 base, 或者 rawImage 有了可能性.
 */

/// Represents an image data provider for loading from a local file URL on disk.
/// Uses this type for adding a disk image to Kingfisher. Compared to loading it
/// directly, you can get benefit of using Kingfisher's extension methods, as well
/// as applying `ImageProcessor`s and storing the image to `ImageCache` of Kingfisher.
public struct LocalFileImageDataProvider: ImageDataProvider {

    // MARK: Public Properties

    /// The file URL from which the image be loaded.
    public let fileURL: URL

    // MARK: Initializers

    /// Creates an image data provider by supplying the target local file URL.
    ///
    /// - Parameters:
    ///   - fileURL: The file URL from which the image be loaded.
    ///   - cacheKey: The key is used for caching the image data. By default,
    ///               the `absoluteString` of `fileURL` is used.
    public init(fileURL: URL, cacheKey: String? = nil) {
        self.fileURL = fileURL
        self.cacheKey = cacheKey ?? fileURL.absoluteString
    }

    // MARK: Protocol Conforming

    // 虽然, 这是一个成员属性. 但是为了和其他的几个协议的要求写在一起, 还是放到了下面.
    /// The key used in cache.
    public var cacheKey: String

    public func data(handler: (Result<Data, Error>) -> Void) {
        // 这里, 使用的 Result 的构造方法, 来捕获 Error
        handler(Result(catching: { try Data(contentsOf: fileURL) }))
    }

    /// The URL of the local file on the disk.
    public var contentURL: URL? {
        return fileURL
    }
}

/// Represents an image data provider for loading image from a given Base64 encoded string.
public struct Base64ImageDataProvider: ImageDataProvider {

    // MARK: Public Properties
    /// The encoded Base64 string for the image.
    public let base64String: String

    // MARK: Initializers

    /// Creates an image data provider by supplying the Base64 encoded string.
    ///
    /// - Parameters:
    ///   - base64String: The Base64 encoded string for an image.
    ///   - cacheKey: The key is used for caching the image data. You need a different key for any different image.
    public init(base64String: String, cacheKey: String) {
        self.base64String = base64String
        self.cacheKey = cacheKey
    }

    // MARK: Protocol Conforming

    /// The key used in cache.
    public var cacheKey: String

    // 这里, 没有办法检测到 Base 64 会出问题, 所以使用 !.
    public func data(handler: (Result<Data, Error>) -> Void) {
        let data = Data(base64Encoded: base64String)!
        handler(.success(data))
    }
}

/// Represents an image data provider for a raw data object.
public struct RawImageDataProvider: ImageDataProvider {

    // MARK: Public Properties

    /// The raw data object to provide to Kingfisher image loader.
    public let data: Data

    // MARK: Initializers

    /// Creates an image data provider by the given raw `data` value and a `cacheKey` be used in Kingfisher cache.
    ///
    /// - Parameters:
    ///   - data: The raw data reprensents an image.
    ///   - cacheKey: The key is used for caching the image data. You need a different key for any different image.
    public init(data: Data, cacheKey: String) {
        self.data = data
        self.cacheKey = cacheKey
    }

    // MARK: Protocol Conforming
    
    /// The key used in cache.
    public var cacheKey: String

    public func data(handler: @escaping (Result<Data, Error>) -> Void) {
        handler(.success(data))
    }
}
