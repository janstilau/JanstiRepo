#if !os(watchOS)

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

// 专门为占位这个概念, 提供了一层抽象.
// 相比于仅仅用 Image 做占位图. 这层抽象的好处就是, 可以让一个 View 当做占位图了.
/// Represents a placeholder type which could be set while loading as well as
/// loading finished without getting an image.
public protocol Placeholder {
    
    /// How the placeholder should be added to a given image view.
    func add(to imageView: KFCrossPlatformImageView)
    
    /// How the placeholder should be removed from a given image view.
    func remove(from imageView: KFCrossPlatformImageView)
}

/// Default implementation of an image placeholder. The image will be set or
/// reset directly for `image` property of the image view.
extension KFCrossPlatformImage: Placeholder {
    
    // 对于一个 Image 来说, 它添加删除就是使用 UIImageView 的 image 属性的设置.
    
    /// How the placeholder should be added to a given image view.
    public func add(to imageView: KFCrossPlatformImageView) { imageView.image = self }
    
    /// How the placeholder should be removed from a given image view.
    public func remove(from imageView: KFCrossPlatformImageView) { imageView.image = nil }
}

/// Default implementation of an arbitrary view as placeholder. The view will be 
/// added as a subview when adding and be removed from its super view when removing.
///
/// To use your customize View type as placeholder, simply let it conforming to 
/// `Placeholder` by `extension MyView: Placeholder {}`.
extension Placeholder where Self: KFCrossPlatformView {
    
    // 对于一个 ImageView 作为 PlaceHolder, 它的 add, remove, 就是将自己添加到对应的 ImageView 上面.
    // 并且完全贴合.
    
    /// How the placeholder should be added to a given image view.
    public func add(to imageView: KFCrossPlatformImageView) {
        imageView.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        
        centerXAnchor.constraint(equalTo: imageView.centerXAnchor).isActive = true
        centerYAnchor.constraint(equalTo: imageView.centerYAnchor).isActive = true
        heightAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
        widthAnchor.constraint(equalTo: imageView.widthAnchor).isActive = true
    }
    
    /// How the placeholder should be removed from a given image view.
    public func remove(from imageView: KFCrossPlatformImageView) {
        removeFromSuperview()
    }
}

#endif
