#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(WatchKit)
import WatchKit
#endif

#if canImport(TVUIKit)
import TVUIKit
#endif

// KF 的各种静态方法, 其实是提供了一个 Builder.
// 而 Builder 的主要的任务, 其实是收集信息.
// 最终, Builder 会通过 setTo 方法, 调用到 View 的.kf.set 各种方法, 并且将自己的收集的信息传递过去.

// If you are not a fan of the kf extension, you can also prefer to use the KF builder and chained the method invocations. The code below is doing the same thing:
// 上面说的很清楚了, Builder, 构造者, 这是 Java 里面非常常见的一个使用方式, 构造者各种属性传值, 仅仅是存值, 而在最后, 会在 build 的时候, 将存储的值传递到真正类的构造函数, 然后类的实例.

/// A helper type to create image setting tasks in a builder pattern.
/// Use methods in this type to create a `KF.Builder` instance and configure image tasks there.
// KF 里面的各种静态方法, 都是提供了 Source 这个属性到 Builder. 然后就是 Builder 的各种属性赋值了.
public enum KF {
    
    /// Creates a builder for a given `Source`.
    /// - Parameter source: The `Source` object defines data information from network or a data provider.
    /// - Returns: A `KF.Builder` for future configuration. After configuring the builder, call `set(to:)`
    ///            to start the image loading.
    public static func source(_ source: Source?) -> KF.Builder {
        Builder(source: source)
    }
    
    /// Creates a builder for a given `Resource`.
    /// - Parameter resource: The `Resource` object defines data information like key or URL.
    /// - Returns: A `KF.Builder` for future configuration. After configuring the builder, call `set(to:)`
    ///            to start the image loading.
    public static func resource(_ resource: Resource?) -> KF.Builder {
        source(resource?.convertToSource())
    }
    
    /// Creates a builder for a given `URL` and an optional cache key.
    /// - Parameters:
    ///   - url: The URL where the image should be downloaded.
    ///   - cacheKey: The key used to store the downloaded image in cache.
    ///               If `nil`, the `absoluteString` of `url` is used as the cache key.
    /// - Returns: A `KF.Builder` for future configuration. After configuring the builder, call `set(to:)`
    ///            to start the image loading.
    // 这里, 之所以可以成功, 是因为 Url 本身就是 Resource 的实现类.
    public static func url(_ url: URL?, cacheKey: String? = nil) -> KF.Builder {
        source(url?.convertToSource(overrideCacheKey: cacheKey))
    }
    
    /// Creates a builder for a given `ImageDataProvider`.
    /// - Parameter provider: The `ImageDataProvider` object contains information about the data.
    /// - Returns: A `KF.Builder` for future configuration. After configuring the builder, call `set(to:)`
    ///            to start the image loading.
    public static func dataProvider(_ provider: ImageDataProvider?) -> KF.Builder {
        source(provider?.convertToSource())
    }
    
    /// Creates a builder for some given raw data and a cache key.
    /// - Parameters:
    ///   - data: The data object from which the image should be created.
    ///   - cacheKey: The key used to store the downloaded image in cache.
    /// - Returns: A `KF.Builder` for future configuration. After configuring the builder, call `set(to:)`
    ///            to start the image loading.
    // 正式因为了有了 Source 这层抽象, 才可以有直接使用 Data 的扩展的可能性.
    public static func data(_ data: Data?, cacheKey: String) -> KF.Builder {
        if let data = data {
            return dataProvider(RawImageDataProvider(data: data, cacheKey: cacheKey))
        } else {
            return dataProvider(nil)
        }
    }
}


extension KF {
    
    /// A builder class to configure an image retrieving task and set it to a holder view or component.
    public class Builder {
        private let source: Source? // 数据的来源.
        
        #if os(watchOS)
        private var placeholder: KFCrossPlatformImage?
        #else
        private var placeholder: Placeholder?
        #endif
        
        // Options 才是众多设置的载体. Builder 暴露除了各种方法, 很多都是在操作里面的数据.
        public var options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions)
        
        public let onFailureDelegate = Delegate<KingfisherError, Void>()
        public let onSuccessDelegate = Delegate<RetrieveImageResult, Void>()
        public let onProgressDelegate = Delegate<(Int64, Int64), Void>()
        
        init(source: Source?) {
            self.source = source
        }
        
        private var resultHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? {
            {
                switch $0 {
                case .success(let result):
                    self.onSuccessDelegate(result)
                case .failure(let error):
                    self.onFailureDelegate(error)
                }
            }
        }
        
        private var progressBlock: DownloadProgressBlock {
            { self.onProgressDelegate(($0, $1)) }
        }
    }
}

/*
 真正的触发了网络设置的代码.
 和 SD 有了很大的不同.
 SD 是从 View 上, 扩展分类, 完成设置图片的操作.
 而 KF 里面, 是设置各种状态, 最后将这些状态, 交给 View.
 */
extension KF.Builder {
    #if !os(watchOS)
    
    /// Builds the image task request and sets it to an image view.
    /// - Parameter imageView: The image view which loads the task and should be set with the image.
    /// - Returns: A task represents the image downloading, if initialized.
    ///            This value is `nil` if the image is being loaded from cache.
    @discardableResult
    public func set(to imageView: KFCrossPlatformImageView) -> DownloadTask? {
        imageView.kf.setImage(
            with: source,
            placeholder: placeholder,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: resultHandler
        )
    }
    
    /// Builds the image task request and sets it to an `NSTextAttachment` object.
    /// - Parameters:
    ///   - attachment: The text attachment object which loads the task and should be set with the image.
    ///   - attributedView: The owner of the attributed string which this `NSTextAttachment` is added.
    /// - Returns: A task represents the image downloading, if initialized.
    ///            This value is `nil` if the image is being loaded from cache.
    @discardableResult
    public func set(to attachment: NSTextAttachment, attributedView: KFCrossPlatformView) -> DownloadTask? {
        let placeholderImage = placeholder as? KFCrossPlatformImage ?? nil
        return attachment.kf.setImage(
            with: source,
            attributedView: attributedView,
            placeholder: placeholderImage,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: resultHandler
        )
    }
    
    #if canImport(UIKit)
    
    /// Builds the image task request and sets it to a button.
    /// - Parameters:
    ///   - button: The button which loads the task and should be set with the image.
    ///   - state: The button state to which the image should be set.
    /// - Returns: A task represents the image downloading, if initialized.
    ///            This value is `nil` if the image is being loaded from cache.
    @discardableResult
    public func set(to button: UIButton, for state: UIControl.State) -> DownloadTask? {
        let placeholderImage = placeholder as? KFCrossPlatformImage ?? nil
        return button.kf.setImage(
            with: source,
            for: state,
            placeholder: placeholderImage,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: resultHandler
        )
    }
    
    /// Builds the image task request and sets it to the background image for a button.
    /// - Parameters:
    ///   - button: The button which loads the task and should be set with the image.
    ///   - state: The button state to which the image should be set.
    /// - Returns: A task represents the image downloading, if initialized.
    ///            This value is `nil` if the image is being loaded from cache.
    @discardableResult
    public func setBackground(to button: UIButton, for state: UIControl.State) -> DownloadTask? {
        let placeholderImage = placeholder as? KFCrossPlatformImage ?? nil
        return button.kf.setBackgroundImage(
            with: source,
            for: state,
            placeholder: placeholderImage,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: resultHandler
        )
    }
    #endif // end of canImport(UIKit)
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Builds the image task request and sets it to a button.
    /// - Parameter button: The button which loads the task and should be set with the image.
    /// - Returns: A task represents the image downloading, if initialized.
    ///            This value is `nil` if the image is being loaded from cache.
    @discardableResult
    public func set(to button: NSButton) -> DownloadTask? {
        let placeholderImage = placeholder as? KFCrossPlatformImage ?? nil
        return button.kf.setImage(
            with: source,
            placeholder: placeholderImage,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: resultHandler
        )
    }
    
    /// Builds the image task request and sets it to the alternative image for a button.
    /// - Parameter button: The button which loads the task and should be set with the image.
    /// - Returns: A task represents the image downloading, if initialized.
    ///            This value is `nil` if the image is being loaded from cache.
    @discardableResult
    public func setAlternative(to button: NSButton) -> DownloadTask? {
        let placeholderImage = placeholder as? KFCrossPlatformImage ?? nil
        return button.kf.setAlternateImage(
            with: source,
            placeholder: placeholderImage,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: resultHandler
        )
    }
    #endif // end of canImport(AppKit)
    #endif // end of !os(watchOS)
    
    #if canImport(WatchKit)
    /// Builds the image task request and sets it to a `WKInterfaceImage` object.
    /// - Parameter interfaceImage: The watch interface image which loads the task and should be set with the image.
    /// - Returns: A task represents the image downloading, if initialized.
    ///            This value is `nil` if the image is being loaded from cache.
    @discardableResult
    public func set(to interfaceImage: WKInterfaceImage) -> DownloadTask? {
        return interfaceImage.kf.setImage(
            with: source,
            placeholder: placeholder,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: resultHandler
        )
    }
    #endif // end of canImport(WatchKit)
    
    #if canImport(TVUIKit)
    /// Builds the image task request and sets it to a TV monogram view.
    /// - Parameter monogramView: The monogram view which loads the task and should be set with the image.
    /// - Returns: A task represents the image downloading, if initialized.
    ///            This value is `nil` if the image is being loaded from cache.
    @available(tvOS 12.0, *)
    @discardableResult
    public func set(to monogramView: TVMonogramView) -> DownloadTask? {
        let placeholderImage = placeholder as? KFCrossPlatformImage ?? nil
        return monogramView.kf.setImage(
            with: source,
            placeholder: placeholderImage,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: resultHandler
        )
    }
    #endif // end of canImport(TVUIKit)
}

#if !os(watchOS)
extension KF.Builder {
    #if os(iOS) || os(tvOS)
    
    /// Sets a placeholder which is used while retrieving the image.
    /// - Parameter placeholder: A placeholder to show while retrieving the image from its source.
    /// - Returns: A `KF.Builder` with changes applied.
    public func placeholder(_ placeholder: Placeholder?) -> Self {
        self.placeholder = placeholder
        return self
    }
    #endif
    
    /// Sets a placeholder image which is used while retrieving the image.
    /// - Parameter placeholder: An image to show while retrieving the image from its source.
    /// - Returns: A `KF.Builder` with changes applied.
    public func placeholder(_ image: KFCrossPlatformImage?) -> Self {
        self.placeholder = image
        return self
    }
}
#endif

extension KF.Builder {
    
    /// Sets the transition for the image task.
    /// - Parameter transition: The desired transition effect when setting the image to image view.
    /// - Returns: A `KF.Builder` with changes applied.
    ///
    /// Kingfisher will use the `transition` to animate the image in if it is downloaded from web.
    /// The transition will not happen when the
    /// image is retrieved from either memory or disk cache by default. If you need to do the transition even when
    /// the image being retrieved from cache, also call `forceRefresh()` on the returned `KF.Builder`.
    
    /*
     存储, 网络 download img 之后, 设置 img 到 View 的切换效果.
     如果直接从缓存里面读取数据, 不做 transition
     这个思路, 和 SDWeb 是一致的.
     */
    public func transition(_ transition: ImageTransition) -> Self {
        options.transition = transition
        return self
    }
    
    /// Sets a fade transition for the image task.
    /// - Parameter duration: The duration of the fade transition.
    /// - Returns: A `KF.Builder` with changes applied.
    ///
    /// Kingfisher will use the fade transition to animate the image in if it is downloaded from web.
    /// The transition will not happen when the
    /// image is retrieved from either memory or disk cache by default. If you need to do the transition even when
    /// the image being retrieved from cache, also call `forceRefresh()` on the returned `KF.Builder`.
    /*
     一个简便的方法, 去设置 transition. 因为 fade 这种效果, 是非常常见的, 所以特意进行了方法的暴露
     */
    public func fade(duration: TimeInterval) -> Self {
        options.transition = .fade(duration)
        return self
    }
    
    /// Sets whether keeping the existing image of image view while setting another image to it.
    /// - Parameter enabled: Whether the existing image should be kept.
    /// - Returns: A `KF.Builder` with changes applied.
    ///
    /// By setting this option, the placeholder image parameter of image view extension method
    /// will be ignored and the current image will be kept while loading or downloading the new image.
    ///
    public func keepCurrentImageWhileLoading(_ enabled: Bool = true) -> Self {
        options.keepCurrentImageWhileLoading = enabled
        return self
    }
    
    /// Sets whether only the first frame from an animated image file should be loaded as a single image.
    /// - Parameter enabled: Whether the only the first frame should be loaded.
    /// - Returns: A `KF.Builder` with changes applied.
    ///
    /// Loading an animated images may take too much memory. It will be useful when you want to display a
    /// static preview of the first frame from an animated image.
    ///
    /// This option will be ignored if the target image is not animated image data.
    ///
    /*
     动图只加载第一张图. 这么看来, KF 里面一定有对于动图的解析.
     */
    public func onlyLoadFirstFrame(_ enabled: Bool = true) -> Self {
        options.onlyLoadFirstFrame = enabled
        return self
    }
    
    /// Sets the image that will be used if an image retrieving task fails.
    /// - Parameter image: The image that will be used when something goes wrong.
    /// - Returns: A `KF.Builder` with changes applied.
    ///
    /// If set and an image retrieving error occurred Kingfisher will set provided image (or empty)
    /// in place of requested one. It's useful when you don't want to show placeholder
    /// during loading time but wants to use some default image when requests will be failed.
    ///
    
    /*
     失败图
     */
    public func onFailureImage(_ image: KFCrossPlatformImage?) -> Self {
        options.onFailureImage = .some(image)
        return self
    }
    
    /// Enables progressive image loading with a specified `ImageProgressive` setting to process the
    /// progressive JPEG data and display it in a progressive way.
    /// - Parameter progressive: The progressive settings which is used while loading.
    /// - Returns: A `KF.Builder` with changes applied.
    public func progressiveJPEG(_ progressive: ImageProgressive? = .default) -> Self {
        options.progressiveJPEG = progressive
        return self
    }
}

// MARK: - Redirect Handler
extension KF {
    
    /// Represents the detail information when a task redirect happens. It is wrapping necessary information for a
    /// `ImageDownloadRedirectHandler`. See that protocol for more information.
    public struct RedirectPayload {
        
        /// The related session data task when the redirect happens. It is
        /// the current `SessionDataTask` which triggers this redirect.
        public let task: SessionDataTask
        
        /// The response received during redirection.
        public let response: HTTPURLResponse
        
        /// The request for redirection which can be modified.
        public let newRequest: URLRequest
        
        /// A closure for being called with modified request.
        public let completionHandler: (URLRequest?) -> Void
    }
}
