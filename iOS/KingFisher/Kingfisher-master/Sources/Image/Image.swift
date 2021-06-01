#if os(macOS)
import AppKit
private var imagesKey: Void?
private var durationKey: Void?
#else
import UIKit
import MobileCoreServices
private var imageSourceKey: Void?
#endif

#if !os(watchOS)
import CoreImage
#endif

import CoreGraphics
import ImageIO

private var animatedImageDataKey: Void?
private var imageFrameCountKey: Void?

// MARK: - Image Properties
extension KingfisherWrapper where Base: KFCrossPlatformImage {
    private(set) var animatedImageData: Data? {
        get { return getAssociatedObject(base, &animatedImageDataKey) }
        set { setRetainedAssociatedObject(base, &animatedImageDataKey, newValue) }
    }
    
    public var imageFrameCount: Int? {
        get { return getAssociatedObject(base, &imageFrameCountKey) }
        set { setRetainedAssociatedObject(base, &imageFrameCountKey, newValue) }
    }
    
    #if os(macOS)
    var cgImage: CGImage? {
        return base.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
    
    var scale: CGFloat {
        return 1.0
    }
    
    private(set) var images: [KFCrossPlatformImage]? {
        get { return getAssociatedObject(base, &imagesKey) }
        set { setRetainedAssociatedObject(base, &imagesKey, newValue) }
    }
    
    private(set) var duration: TimeInterval {
        get { return getAssociatedObject(base, &durationKey) ?? 0.0 }
        set { setRetainedAssociatedObject(base, &durationKey, newValue) }
    }
    
    var size: CGSize {
        return base.representations.reduce(.zero) { size, rep in
            let width = max(size.width, CGFloat(rep.pixelsWide))
            let height = max(size.height, CGFloat(rep.pixelsHigh))
            return CGSize(width: width, height: height)
        }
    }
    #else
    var cgImage: CGImage? { return base.cgImage }
    var scale: CGFloat { return base.scale }
    var images: [KFCrossPlatformImage]? { return base.images }
    var duration: TimeInterval { return base.duration }
    var size: CGSize { return base.size }
    
    private(set) var imageSource: CGImageSource? {
        get { return getAssociatedObject(base, &imageSourceKey) }
        set { setRetainedAssociatedObject(base, &imageSourceKey, newValue) }
    }
    #endif
    
    // Bitmap memory cost with bytes.
    var cost: Int {
        let pixel = Int(size.width * size.height * scale * scale)
        guard let cgImage = cgImage else {
            return pixel * 4
        }
        return pixel * cgImage.bitsPerPixel / 8
    }
}

// MARK: - Image Conversion
extension KingfisherWrapper where Base: KFCrossPlatformImage {
    #if os(macOS)
    static func image(cgImage: CGImage, scale: CGFloat, refImage: KFCrossPlatformImage?) -> KFCrossPlatformImage {
        return KFCrossPlatformImage(cgImage: cgImage, size: .zero)
    }
    
    /// Normalize the image. This getter does nothing on macOS but return the image itself.
    public var normalized: KFCrossPlatformImage { return base }
    
    #else
    /// Creating an image from a give `CGImage` at scale and orientation for refImage. The method signature is for
    /// compatibility of macOS version.
    static func image(cgImage: CGImage, scale: CGFloat, refImage: KFCrossPlatformImage?) -> KFCrossPlatformImage {
        return KFCrossPlatformImage(cgImage: cgImage, scale: scale, orientation: refImage?.imageOrientation ?? .up)
    }
    
    /// Returns normalized image for current `base` image.
    /// This method will try to redraw an image with orientation and scale considered.
    public var normalized: KFCrossPlatformImage {
        // prevent animated image (GIF) lose it's images
        guard images == nil else { return base.copy() as! KFCrossPlatformImage }
        // No need to do anything if already up
        guard base.imageOrientation != .up else { return base.copy() as! KFCrossPlatformImage }
        
        return draw(to: size, inverting: true, refImage: KFCrossPlatformImage()) {
            fixOrientation(in: $0)
            return true
        }
    }
    
    func fixOrientation(in context: CGContext) {
        
        var transform = CGAffineTransform.identity
        
        let orientation = base.imageOrientation
        
        switch orientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: size.height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.rotated(by: .pi / 2.0)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: size.height)
            transform = transform.rotated(by: .pi / -2.0)
        case .up, .upMirrored:
            break
        #if compiler(>=5)
        @unknown default:
            break
        #endif
        }
        
        //Flip image one more time if needed to, this is to prevent flipped image
        switch orientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: size.width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: size.height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .up, .down, .left, .right:
            break
        #if compiler(>=5)
        @unknown default:
            break
        #endif
        }
        
        context.concatenate(transform)
        switch orientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            context.draw(cgImage!, in: CGRect(x: 0, y: 0, width: size.height, height: size.width))
        default:
            context.draw(cgImage!, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        }
    }
    #endif
}

// MARK: - Image Representation
extension KingfisherWrapper where Base: KFCrossPlatformImage {
    /// Returns PNG representation of `base` image.
    ///
    /// - Returns: PNG data of image.
    public func pngRepresentation() -> Data? {
        #if os(macOS)
        guard let cgImage = cgImage else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
        #else
        return base.pngData()
        #endif
    }
    
    /// Returns JPEG representation of `base` image.
    ///
    /// - Parameter compressionQuality: The compression quality when converting image to JPEG data.
    /// - Returns: JPEG data of image.
    public func jpegRepresentation(compressionQuality: CGFloat) -> Data? {
        #if os(macOS)
        guard let cgImage = cgImage else {
            return nil
        }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using:.jpeg, properties: [.compressionFactor: compressionQuality])
        #else
        return base.jpegData(compressionQuality: compressionQuality)
        #endif
    }
    
    /// Returns GIF representation of `base` image.
    ///
    /// - Returns: Original GIF data of image.
    public func gifRepresentation() -> Data? {
        return animatedImageData
    }
    
    /// Returns a data representation for `base` image, with the `format` as the format indicator.
    ///
    /// - Parameter format: The format in which the output data should be. If `unknown`, the `base` image will be
    ///                     converted in the PNG representation.
    ///
    /// - Returns: The output data representing.
    
    /// Returns a data representation for `base` image, with the `format` as the format indicator.
    /// - Parameters:
    ///   - format: The format in which the output data should be. If `unknown`, the `base` image will be
    ///   converted in the PNG representation.
    ///   - compressionQuality: The compression quality when converting image to a lossy format data.
    public func data(format: ImageFormat, compressionQuality: CGFloat = 1.0) -> Data? {
        return autoreleasepool { () -> Data? in
            let data: Data?
            switch format {
            case .PNG: data = pngRepresentation()
            case .JPEG: data = jpegRepresentation(compressionQuality: compressionQuality)
            case .GIF: data = gifRepresentation()
            case .unknown: data = normalized.kf.pngRepresentation()
            }
            
            return data
        }
    }
}

// 不仅仅在类内使用 Mark, 也可以在 Extension 的头部使用进行标识.
// 因为 Swfit 的 Extensin 没有名字, 所以用这种方式, 能够更加清晰的标明, 这个 Extension 的作用.

// MARK: - Creating Images
extension KingfisherWrapper where Base: KFCrossPlatformImage {
    
    /// Creates an animated image from a given data and options. Currently only GIF data is supported.
    ///
    /// - Parameters:
    ///   - data: The animated image data.
    ///   - options: Options to use when creating the animated image.
    /// - Returns: An `Image` object represents the animated image.
    ///            It is in form of an array of image frames with a certain duration.
    ///            `nil` if anything wrong when creating animated image.
    public static func animatedImage(data: Data, options: ImageCreatingOptions) -> KFCrossPlatformImage? {
        let info: [String: Any] = [
            // as 并不是免费的, 它仅仅是 init 方法的简便使用.
            kCGImageSourceShouldCache as String: true,
            kCGImageSourceTypeIdentifierHint as String: kUTTypeGIF
        ]
        
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, info as CFDictionary) else {
            return nil
        }
        
        /*
         An image view can store an animated image sequence and play all or part of that sequence. You specify an image sequence as an array of UIImage objects and assign them to the animationImages property. Once assigned, you can use the methods and properties of this class to configure the animation timing and to start and stop the animation.
         You can also construct a single UIImage object from a sequence of individual images using the animatedImage(with:duration:) method. Doing so yields the same results as if you had assigned the individual images to the animationImages property.
         
         从这段文档可以看出, ImageView 的 animationImages 数组, 和 animatedImage 是同样的一件事.
         在内部, 也应该是使用一个处理逻辑.
         */
        
        var image: KFCrossPlatformImage?
        if options.preloadAll || options.onlyFirstFrame {
            // Use `images` image if you want to preload all animated data
            guard let animatedImage = GIFAnimatedImage(from: imageSource,
                                                       for: info,
                                                       options: options) else {
                return nil
            }
            if options.onlyFirstFrame {
                image = animatedImage.images.first
            } else {
                let duration = options.duration <= 0.0 ? animatedImage.duration : options.duration
                // 最终, 是使用了 GIFAnimatedImage 中存储的数据, 然后生成了单一的一个 IMAGE.
                image = .animatedImage(with: animatedImage.images, duration: duration)
            }
            image?.kf.animatedImageData = data
        } else {
            image = KFCrossPlatformImage(data: data, scale: options.scale)
            var kf = image?.kf
            kf?.imageSource = imageSource
            kf?.animatedImageData = data
        }
        
        image?.kf.imageFrameCount = Int(CGImageSourceGetCount(imageSource))
        return image
    }
    
    /// Creates an image from a given data and options. `.JPEG`, `.PNG` or `.GIF` is supported. For other
    /// image format, image initializer from system will be used. If no image object could be created from
    /// the given `data`, `nil` will be returned.
    ///
    /// - Parameters:
    ///   - data: The image data representation.
    ///   - options: Options to use when creating the image.
    /// - Returns: An `Image` object represents the image if created. If the `data` is invalid or not supported, `nil`
    ///            will be returned.
    
    // 这是将 Data 转化为 Image 的统一的入口. 无论是网络下载的数据, 缓存的数据, 都会经过这个方法.
    // 如果是 JPG, PNG 的图, 直接使用系统的 Image init 方法.
    // 如果是 GIF, 有着特殊的解析的方式. 并且, 会将生成的 Image 图上, 挂钩上 frameCount, animateData 这些数据.
    
    public static func image(data: Data, options: ImageCreatingOptions) -> KFCrossPlatformImage? {
        var image: KFCrossPlatformImage?
        switch data.kf.imageFormat {
        case .JPEG:
            image = KFCrossPlatformImage(data: data, scale: options.scale)
        case .PNG:
            image = KFCrossPlatformImage(data: data, scale: options.scale)
        case .GIF:
            image = KingfisherWrapper.animatedImage(data: data, options: options)
        case .unknown:
            image = KFCrossPlatformImage(data: data, scale: options.scale)
        }
        return image
    }
    
    /// Creates a downsampled image from given data to a certain size and scale.
    ///
    /// - Parameters:
    ///   - data: The image data contains a JPEG or PNG image.
    ///   - pointSize: The target size in point to which the image should be downsampled.
    ///   - scale: The scale of result image.
    /// - Returns: A downsampled `Image` object following the input conditions.
    ///
    /// - Note:
    /// Different from image `resize` methods, downsampling will not render the original
    /// input image in pixel format. It does downsampling from the image data, so it is much
    /// more memory efficient and friendly. Choose to use downsampling as possible as you can.
    ///
    /// The input size should be smaller than the size of input image. If it is larger than the
    /// original image size, the result image will be the same size of input without downsampling.
    public static func downsampledImage(data: Data, to pointSize: CGSize, scale: CGFloat) -> KFCrossPlatformImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }
        
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * scale
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels] as CFDictionary
        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        return KingfisherWrapper.image(cgImage: downsampledImage, scale: scale, refImage: nil)
    }
}
