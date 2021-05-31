#if !os(watchOS)

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
public typealias IndicatorView = NSView
#else
import UIKit
public typealias IndicatorView = UIView
#endif


// 实际上, 日常使用的其实是这个 Type 类.
// 在 Type 的 set 方法里面, 其实是根据 case 的值, 生成了对应的 View 的类型的.
// 只能通过 enum 对于 ImageView 进行 indicator 的赋值.

/// Represents the activity indicator type which should be added to
/// an image view when an image is being downloaded.
///
/// - none: No indicator.
/// - activity: Uses the system activity indicator.
/// - image: Uses an image as indicator. GIF is supported.
/// - custom: Uses a custom indicator. The type of associated value should conform to the `Indicator` protocol.
public enum IndicatorType {
    /// No indicator.
    case none
    /// Uses the system activity indicator.
    case activity
    /// Uses an image as indicator. GIF is supported.
    case image(imageData: Data)
    /// Uses a custom indicator. The type of associated value should conform to the `Indicator` protocol.
    case custom(indicator: Indicator)
}

/// An indicator type which can be used to show the download task is in progress.
public protocol Indicator {
    
    /// Called when the indicator should start animating.
    func startAnimatingView()
    
    /// Called when the indicator should stop animating.
    func stopAnimatingView()

    /// Center offset of the indicator. Kingfisher will use this value to determine the position of
    /// indicator in the super view.
    var centerOffset: CGPoint { get }
     
    /// The indicator view which would be added to the super view.
    var view: IndicatorView { get }

    /// The size strategy used when adding the indicator to image view.
    /// - Parameter imageView: The super view of indicator.
    func sizeStrategy(in imageView: KFCrossPlatformImageView) -> IndicatorSizeStrategy
}

public enum IndicatorSizeStrategy {
    case intrinsicSize
    case full
    case size(CGSize)
}

extension Indicator {
    
    /// Default implementation of `centerOffset` of `Indicator`. The default value is `.zero`, means that there is
    /// no offset for the indicator view.
    public var centerOffset: CGPoint { return .zero }


    /// Default implementation of `centerOffset` of `Indicator`. The default value is `.full`, means that the indicator
    /// will pin to the same height and width as the image view.
    public func sizeStrategy(in imageView: KFCrossPlatformImageView) -> IndicatorSizeStrategy {
        return .full
    }
}

// 对于系统的菊花的封装, 一个新的类型, 这个类型, 实现 Indicator 协议.
// 该使用 final 的地方, 不要吝啬
final class ActivityIndicator: Indicator {

    #if os(macOS)
    private let activityIndicatorView: NSProgressIndicator
    #else
    private let activityIndicatorView: UIActivityIndicatorView
    #endif
    private var animatingCount = 0

    var view: IndicatorView {
        return activityIndicatorView
    }

    func startAnimatingView() {
        if animatingCount == 0 {
            #if os(macOS)
            activityIndicatorView.startAnimation(nil)
            #else
            activityIndicatorView.startAnimating()
            #endif
            activityIndicatorView.isHidden = false
        }
        animatingCount += 1
    }

    func stopAnimatingView() {
        animatingCount = max(animatingCount - 1, 0)
        if animatingCount == 0 {
            #if os(macOS)
                activityIndicatorView.stopAnimation(nil)
            #else
                activityIndicatorView.stopAnimating()
            #endif
            activityIndicatorView.isHidden = true
        }
    }

    func sizeStrategy(in imageView: KFCrossPlatformImageView) -> IndicatorSizeStrategy {
        return .intrinsicSize
    }

    init() {
        #if os(macOS)
            activityIndicatorView = NSProgressIndicator(frame: CGRect(x: 0, y: 0, width: 16, height: 16))
            activityIndicatorView.controlSize = .small
            activityIndicatorView.style = .spinning
        #else
            let indicatorStyle: UIActivityIndicatorView.Style

            #if os(tvOS)
            if #available(tvOS 13.0, *) {
                indicatorStyle = UIActivityIndicatorView.Style.large
            } else {
                indicatorStyle = UIActivityIndicatorView.Style.white
            }
            #else
            if #available(iOS 13.0, * ) {
                indicatorStyle = UIActivityIndicatorView.Style.medium
            } else {
                indicatorStyle = UIActivityIndicatorView.Style.gray
            }
            #endif

            activityIndicatorView = UIActivityIndicatorView(style: indicatorStyle)
        #endif
    }
}

#if canImport(UIKit)
extension UIActivityIndicatorView.Style {
    #if compiler(>=5.1)
    #else
    static let large = UIActivityIndicatorView.Style.white
    #if !os(tvOS)
    static let medium = UIActivityIndicatorView.Style.gray
    #endif
    #endif
}
#endif

// MARK: - ImageIndicator
// Displays an ImageView. Supports gif
final class ImageIndicator: Indicator {
    private let animatedImageIndicatorView: KFCrossPlatformImageView

    var view: IndicatorView {
        return animatedImageIndicatorView
    }

    init?(
        imageData data: Data,
        processor: ImageProcessor = DefaultImageProcessor.default,
        options: KingfisherParsedOptionsInfo? = nil)
    {
        var options = options ?? KingfisherParsedOptionsInfo(nil)
        // Use normal image view to show animations, so we need to preload all animation data.
        if !options.preloadAllAnimationData {
            options.preloadAllAnimationData = true
        }
        
        // 在这里, 还是使用了类库自己的图形数据解析器.
        guard let image = processor.process(item: .data(data), options: options) else {
            return nil
        }

        animatedImageIndicatorView = KFCrossPlatformImageView()
        animatedImageIndicatorView.image = image
        
        #if os(macOS)
            // Need for gif to animate on macOS
            animatedImageIndicatorView.imageScaling = .scaleNone
            animatedImageIndicatorView.canDrawSubviewsIntoLayer = true
        #else
            animatedImageIndicatorView.contentMode = .center
        #endif
    }

    func startAnimatingView() {
        #if os(macOS)
            animatedImageIndicatorView.animates = true
        #else
            animatedImageIndicatorView.startAnimating()
        #endif
        animatedImageIndicatorView.isHidden = false
    }

    func stopAnimatingView() {
        #if os(macOS)
            animatedImageIndicatorView.animates = false
        #else
            animatedImageIndicatorView.stopAnimating()
        #endif
        animatedImageIndicatorView.isHidden = true
    }
}

#endif
