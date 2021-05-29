#if !os(watchOS)
#if canImport(UIKit)
import UIKit
import ImageIO


// 虽然, 定义了这样一个协议, 但是没有在库里面真实的使用过.

/// Protocol of `AnimatedImageView`.
public protocol AnimatedImageViewDelegate: AnyObject {
    
    /// Called after the animatedImageView has finished each animation loop.
    ///
    /// - Parameters:
    ///   - imageView: The `AnimatedImageView` that is being animated.
    ///   - count: The looped count.
    func animatedImageView(_ imageView: AnimatedImageView, didPlayAnimationLoops count: UInt)
    
    /// Called after the `AnimatedImageView` has reached the max repeat count.
    ///
    /// - Parameter imageView: The `AnimatedImageView` that is being animated.
    func animatedImageViewDidFinishAnimating(_ imageView: AnimatedImageView)
}

extension AnimatedImageViewDelegate {
    public func animatedImageView(_ imageView: AnimatedImageView, didPlayAnimationLoops count: UInt) {}
    public func animatedImageViewDidFinishAnimating(_ imageView: AnimatedImageView) {}
}

let KFRunLoopModeCommon = RunLoop.Mode.common

/// Represents a subclass of `UIImageView` for displaying animated image.
/// Different from showing animated image in a normal `UIImageView` (which load all frames at one time),
/// `AnimatedImageView` only tries to load several frames (defined by `framePreloadCount`) to reduce memory usage.
/// It provides a tradeoff between memory usage and CPU time. If you have a memory issue when using a normal image
/// view to load GIF data, you could give this class a try.
///
/// Kingfisher supports setting GIF animated data to either `UIImageView` and `AnimatedImageView` out of box. So
/// it would be fairly easy to switch between them.

// 这应该是 SDAnimationImageView 的 Swift 版本实现.

open class AnimatedImageView: UIImageView {
    
    // 这个内部类型, 就是为了进行循环引用的打破的.
    class TargetProxy {
        private weak var target: AnimatedImageView?
        
        init(target: AnimatedImageView) {
            self.target = target
        }
        
        // 当屏幕刷新之后, 调用 updateFrameIfNeeded
        @objc func onScreenUpdate() {
            target?.updateFrameIfNeeded()
        }
    }
    
    /// Enumeration that specifies repeat count of GIF
    // 相比较于 Int 的 -1, 1, 特定的 Int 值来表示以下的三个含义.
    // 这种 enum 的字符串表示, 具有更棒的表示. 同时, 由于关联值的存在, 让 finite 提供特定数量也成为了可能.
    public enum RepeatCount: Equatable {
        case once
        case finite(count: UInt)
        case infinite
        
        public static func ==(lhs: RepeatCount, rhs: RepeatCount) -> Bool {
            switch (lhs, rhs) {
            case let (.finite(l), .finite(r)):
                return l == r
            case (.once, .once),
                 (.infinite, .infinite):
                return true
            case (.once, .finite(let count)),
                 (.finite(let count), .once):
                return count == 1
            case (.once, _),
                 (.infinite, _),
                 (.finite, _):
                return false
            }
        }
    }
    
    // MARK: - Public property
    /// Whether automatically play the animation when the view become visible. Default is `true`.
    public var autoPlayAnimatedImage = true
    
    /// The count of the frames should be preloaded before shown.
    public var framePreloadCount = 10
    
    /// Specifies whether the GIF frames should be pre-scaled to the image view's size or not.
    /// If the downloaded image is larger than the image view's size, it will help to reduce some memory use.
    /// Default is `true`.
    public var needsPrescaling = true
    
    /// Decode the GIF frames in background thread before using. It will decode frames data and do a off-screen
    /// rendering to extract pixel information in background. This can reduce the main thread CPU usage.
    public var backgroundDecode = true
    
    /// The animation timer's run loop mode. Default is `RunLoop.Mode.common`.
    /// Set this property to `RunLoop.Mode.default` will make the animation pause during UIScrollView scrolling.
    // RunLoopMode 的改变, 其实就是改变 DisplayLink 添加到 Runloop 的 Mode.
    public var runLoopMode = KFRunLoopModeCommon {
        willSet {
            guard runLoopMode != newValue else { return }
            stopAnimating()
            displayLink.remove(from: .main, forMode: runLoopMode)
            displayLink.add(to: .main, forMode: newValue)
            startAnimating()
        }
    }
    
    /// The repeat count. The animated image will keep animate until it the loop count reaches this value.
    /// Setting this value to another one will reset current animation.
    ///
    /// Default is `.infinite`, which means the animation will last forever.
    
    // 可以改变, Gif 动画的重复次数.
    // 每次改变, 都会重新生成 Animator. 然后调用重绘的操作.
    public var repeatCount = RepeatCount.infinite {
        didSet {
            if oldValue != repeatCount {
                reset()
                setNeedsDisplay()
                layer.setNeedsDisplay()
            }
        }
    }
    
    /// Delegate of this `AnimatedImageView` object. See `AnimatedImageViewDelegate` protocol for more.
    public weak var delegate: AnimatedImageViewDelegate?
    
    /// The `Animator` instance that holds the frames of a specific image in memory.
    public private(set) var animator: Animator?
    
    // MARK: - Private property
    // Dispatch queue used for preloading images.
    private lazy var preloadQueue: DispatchQueue = {
        return DispatchQueue(label: "com.onevcat.Kingfisher.Animator.preloadQueue")
    }()
    
    // A flag to avoid invalidating the displayLink on deinit if it was never created, because displayLink is so lazy.
    // 为了, 使用一个 lazy 的属性, 只能通过这种方式去判断.
    // 使用了 lazy, 就是为了避免使用 Optinal 带来的不断地判断 ? 的麻烦之处.
    // 但是, 如果需要管理 lazy 属性的生命, 就需要额外的设置标志位了.
    
    private var isDisplayLinkInitialized: Bool = false
    
    // A display link that keeps calling the `updateFrame` method on every screen refresh.
    private lazy var displayLink: CADisplayLink = {
        isDisplayLinkInitialized = true
        let displayLink = CADisplayLink(target: TargetProxy(target: self), selector: #selector(TargetProxy.onScreenUpdate))
        displayLink.add(to: .main, forMode: runLoopMode)
        displayLink.isPaused = true
        return displayLink
    }()
    
    // MARK: - Override
    override open var image: KFCrossPlatformImage? {
        didSet {
            if image != oldValue {
                reset()
            }
            setNeedsDisplay()
            layer.setNeedsDisplay()
        }
    }
    
    open override var isHighlighted: Bool {
        get {
            super.isHighlighted
        }
        set {
            // Highlighted image is unsupported for animated images.
            // See https://github.com/onevcat/Kingfisher/issues/1679
            if displayLink.isPaused {
                super.isHighlighted = newValue
            }
        }
    }
    
    deinit {
        if isDisplayLinkInitialized {
            displayLink.invalidate()
        }
    }
    
    override open var isAnimating: Bool {
        if isDisplayLinkInitialized {
            return !displayLink.isPaused
        } else {
            return super.isAnimating
        }
    }
    
    // 开启动画, 就是开启定时器.
    override open func startAnimating() {
        guard !isAnimating else { return }
        guard let animator = animator else { return }
        guard !animator.isReachMaxRepeatCount else { return }
        
        displayLink.isPaused = false
    }
    
    // 关闭动画, 就是关闭定时器.
    override open func stopAnimating() {
        super.stopAnimating()
        if isDisplayLinkInitialized {
            displayLink.isPaused = true
        }
    }
    
    // 这里, 其实就是 Gif 图能够显示的原因了.
    // displayLink 会跟随着屏幕, 判断是否应该生成新的图片了. 如果是, 那么就调用 needDisplay 方法, 刷新 UIImageView
    // 在 Layer 的代理方法里面, 调用到了 func display(_ layer: CALayer) 方法, 将新的图, 设置给 Layer 的 image
    override open func display(_ layer: CALayer) {
        if let currentFrame = animator?.currentFrameImage {
            layer.contents = currentFrame.cgImage
        } else {
            layer.contents = image?.cgImage
        }
    }
    
    override open func didMoveToWindow() {
        super.didMoveToWindow()
        didMove()
    }
    
    override open func didMoveToSuperview() {
        super.didMoveToSuperview()
        didMove()
    }
    
    // This is for back compatibility that using regular `UIImageView` to show animated image.
    override func shouldPreloadAllAnimation() -> Bool {
        return false
    }
    
    // Reset the animator.
    private func reset() {
        animator = nil
        // 实际上, 需要的 ImageSource 这个属性, 是挂钩到了 Image 上面.
        if let image = image, let imageSource = image.kf.imageSource {
            let targetSize = bounds.scaled(UIScreen.main.scale).size
            let animator = Animator(
                imageSource: imageSource,
                contentMode: contentMode,
                size: targetSize,
                imageSize: image.kf.size,
                imageScale: image.kf.scale,
                framePreloadCount: framePreloadCount,
                repeatCount: repeatCount,
                preloadQueue: preloadQueue)
            // 经常用到这种设计. 真正执行的, 是另外一块业务类, 但是这个业务类的各种配置, 是启动类传递过去的.
            // 启动类可能会有各种各样的属性, 这些属性, 会影响到各种功能类的细微的功能点. 但是, 作为用户使用的入口, 只能是在启动类里面, 占据一个属性.
            animator.delegate = self
            animator.needsPrescaling = needsPrescaling
            animator.backgroundDecode = backgroundDecode
            animator.prepareFramesAsynchronously() // 在 Init 的时候, 之后, 就会进行资源的预先准备.
            self.animator = animator
        }
        didMove()
    }
    
    // 当, ImageView 的 Window 变化的时候, 或者 superView 变化的时候, 会调用到这个方法.
    // 在这个方法里面, 统一进行动画的控制.
    private func didMove() {
        if autoPlayAnimatedImage && animator != nil {
            if let _ = superview, let _ = window {
                startAnimating()
            } else {
                stopAnimating()
            }
        }
    }
    
    /// Update the current frame with the displayLink duration.
    // 定时器, 不断的刷新调用该方法, 进行 ImageView 的显示数据的刷新.
    private func updateFrameIfNeeded() {
        guard let animator = animator else {
            return
        }
        
        guard !animator.isFinished else {
            stopAnimating()
            delegate?.animatedImageViewDidFinishAnimating(self)
            return
        }
        
        let duration: CFTimeInterval
        // preferredFramesPerSecond 这个值, 代表着刷新的事件频率
        // 如果, 通过修改 displayLink 的这个值, 可以改变定时器的调用间隔.
        // 这里, 也就是说, gif 图应该将该值考虑在内, 判断是不是应该修改 image 的显示.
        let preferredFramesPerSecond = displayLink.preferredFramesPerSecond
        if preferredFramesPerSecond == 0 {
            duration = displayLink.duration
        } else {
            // Some devices (like iPad Pro 10.5) will have a different FPS.
            duration = 1.0 / TimeInterval(preferredFramesPerSecond)
        }
        
        // 使用 animator 来判断, 是不是应该刷新显示.
        // 在 Animator 的内部, 会根据 gif 的状态, 来判断是否应该刷新.
        // 例如, gif 里面每张图其实会有 duration 的概念的. 如果一张图的 duration 比较大, 那么其实它一直不刷新, 才是合理的, 是 gif 的制作者的原始意图.
        animator.shouldChangeFrame(with: duration) { [weak self] hasNewFrame in
            if hasNewFrame {
                self?.layer.setNeedsDisplay()
            }
        }
    }
}

protocol AnimatorDelegate: AnyObject {
    func animator(_ animator: AnimatedImageView.Animator, didPlayAnimationLoops count: UInt)
}

extension AnimatedImageView: AnimatorDelegate {
    func animator(_ animator: Animator, didPlayAnimationLoops count: UInt) {
        delegate?.animatedImageView(self, didPlayAnimationLoops: count)
    }
}

extension AnimatedImageView {
    
    // Represents a single frame in a GIF.
    struct AnimatedFrame {
        
        // The image to display for this frame. Its value is nil when the frame is removed from the buffer.
        let image: UIImage?
        
        // The duration that this frame should remain active.
        let duration: TimeInterval
        
        // A placeholder frame with no image assigned.
        // Used to replace frames that are no longer needed in the animation.
        var placeholderFrame: AnimatedFrame {
            return AnimatedFrame(image: nil, duration: duration)
        }
        
        // Whether this frame instance contains an image or not.
        var isPlaceholder: Bool {
            return image == nil
        }
        
        // Returns a new instance from an optional image.
        //
        // - parameter image: An optional `UIImage` instance to be assigned to the new frame.
        // - returns: An `AnimatedFrame` instance.
        // 这类, 之所以用实例方法, 是因为想要复用 duration 的值. 不想再次计算了
        func makeAnimatedFrame(image: UIImage?) -> AnimatedFrame {
            return AnimatedFrame(image: image, duration: duration)
        }
    }
}

extension AnimatedImageView {
    
    // MARK: - Animator
    
    /// An animator which used to drive the data behind `AnimatedImageView`.
    // 这个类, 就是不断地抽取 Gif 里面的数据, 制作成为 Image, 供 UIImageView 使用的.
    
    public class Animator {
        private let size: CGSize
        
        private let imageSize: CGSize
        private let imageScale: CGFloat
        
        /// The maximum count of image frames that needs preload.
        public let maxFrameCount: Int
        
        private let imageSource: CGImageSource
        private let maxRepeatCount: RepeatCount
        
        private let maxTimeStep: TimeInterval = 1.0
        private let animatedFrames = SafeArray<AnimatedFrame>() // 其他的数据, 都是常量值.
        
        // 其他的可变值, 都在代码层次上, 进行了线程修改的控制.
        // 所以, 只有 animatedFrames 的数据修改, 有了线程的保护.
        private var frameCount = 0
        private var timeSinceLastFrameChange: TimeInterval = 0.0
        private var currentRepeatCount: UInt = 0
        
        var isFinished: Bool = false
        
        var needsPrescaling = true
        
        var backgroundDecode = true
        
        weak var delegate: AnimatorDelegate?
        
        // Total duration of one animation loop
        var loopDuration: TimeInterval = 0
        
        /// The image of the current frame.
        public var currentFrameImage: UIImage? {
            return frame(at: currentFrameIndex)
        }
        
        /// The duration of the current active frame duration.
        public var currentFrameDuration: TimeInterval {
            return duration(at: currentFrameIndex)
        }
        
        /// The index of the current animation frame.
        public internal(set) var currentFrameIndex = 0 {
            didSet {
                previousFrameIndex = oldValue
            }
        }
        
        var previousFrameIndex = 0 {
            didSet {
                preloadQueue.async {
                    self.updatePreloadedFrames()
                }
            }
        }
        
        var isReachMaxRepeatCount: Bool {
            switch maxRepeatCount {
            case .once:
                return currentRepeatCount >= 1
            case .finite(let maxCount):
                return currentRepeatCount >= maxCount
            case .infinite:
                return false
            }
        }
        
        /// Whether the current frame is the last frame or not in the animation sequence.
        public var isLastFrame: Bool {
            return currentFrameIndex == frameCount - 1
        }
        
        var preloadingIsNeeded: Bool {
            return maxFrameCount < frameCount - 1
        }
        
        var contentMode = UIView.ContentMode.scaleToFill
        
        private lazy var preloadQueue: DispatchQueue = {
            return DispatchQueue(label: "com.onevcat.Kingfisher.Animator.preloadQueue")
        }()
        
        /// Creates an animator with image source reference.
        ///
        /// - Parameters:
        ///   - source: The reference of animated image.
        ///   - mode: Content mode of the `AnimatedImageView`.
        ///   - size: Size of the `AnimatedImageView`.
        ///   - imageSize: Size of the `KingfisherWrapper`.
        ///   - imageScale: Scale of the `KingfisherWrapper`.
        ///   - count: Count of frames needed to be preloaded.
        ///   - repeatCount: The repeat count should this animator uses.
        ///   - preloadQueue: Dispatch queue used for preloading images.
        init(imageSource source: CGImageSource,
             contentMode mode: UIView.ContentMode,
             size: CGSize,
             imageSize: CGSize,
             imageScale: CGFloat,
             framePreloadCount count: Int,
             repeatCount: RepeatCount,
             preloadQueue: DispatchQueue) {
            self.imageSource = source
            self.contentMode = mode
            self.size = size
            self.imageSize = imageSize
            self.imageScale = imageScale
            self.maxFrameCount = count
            self.maxRepeatCount = repeatCount
            self.preloadQueue = preloadQueue
            
            GraphicsContext.begin(size: imageSize, scale: imageScale)
        }
        
        deinit {
            GraphicsContext.end()
        }
        
        /// Gets the image frame of a given index.
        /// - Parameter index: The index of desired image.
        /// - Returns: The decoded image at the frame. `nil` if the index is out of bound or the image is not yet loaded.
        // 从, 存储的图里面, 读取应该进行显示的 Image, 然后显示出来.
        public func frame(at index: Int) -> KFCrossPlatformImage? {
            return animatedFrames[index]?.image
        }
        
        public func duration(at index: Int) -> TimeInterval {
            return animatedFrames[index]?.duration  ?? .infinity
        }
        
        func prepareFramesAsynchronously() {
            frameCount = Int(CGImageSourceGetCount(imageSource))
            animatedFrames.reserveCapacity(frameCount)
            preloadQueue.async { [weak self] in
                self?.setupAnimatedFrames()
            }
        }
        
        // 如果, 当前的经过的时间, 超过了当前帧的时间, 那么就改变当前帧的 IDX 值, 通知外界该刷新了.
        func shouldChangeFrame(with duration: CFTimeInterval, handler: (Bool) -> Void) {
            incrementTimeSinceLastFrameChange(with: duration)
            
            if currentFrameDuration > timeSinceLastFrameChange {
                handler(false)
            } else {
                resetTimeSinceLastFrameChange()
                incrementCurrentFrameIndex()
                handler(true)
            }
        }
        
        // setupAnimatedFrames 会在异步线程里面调用. GIFAnimatedImage.getFrameDuration 也会占用资源.
        private func setupAnimatedFrames() {
            resetAnimatedFrames()
            
            var duration: TimeInterval = 0
            
            (0..<frameCount).forEach { index in
                let frameDuration = GIFAnimatedImage.getFrameDuration(from: imageSource, at: index)
                duration += min(frameDuration, maxTimeStep)
                // 提前, 插入了一个 placeHolder 的 Image 进入. 这样, frame(at index: Int) 的实现就会变得非常的简单.
                animatedFrames.append(AnimatedFrame(image: nil, duration: frameDuration))
                
                if index > maxFrameCount { return }
                
                animatedFrames[index] = animatedFrames[index]?.makeAnimatedFrame(image: loadFrame(at: index))
            }
            
            self.loopDuration = duration
        }
        
        private func resetAnimatedFrames() {
            animatedFrames.removeAll()
        }
        
        // 这里是实际的读取图的逻辑所在.
        private func loadFrame(at index: Int) -> UIImage? {
            let resize = needsPrescaling && size != .zero
            let options: [CFString: Any]?
            if resize {
                options = [
                    kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceShouldCacheImmediately: true,
                    kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height)
                ]
            } else {
                options = nil
            }
            
            guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, index, options as CFDictionary?) else {
                return nil
            }
            
            let image = KFCrossPlatformImage(cgImage: cgImage)
            
            guard let context = GraphicsContext.current(size: imageSize,
                                                        scale: imageScale,
                                                        inverting: true,
                                                        cgImage: cgImage) else {
                return image
            }
            
            // 这里, 取得了 CGImage 之后, 专门的用 context 画出来的.
            return backgroundDecode ? image.kf.decoded(on: context) : image
        }
        
        private func updatePreloadedFrames() {
            guard preloadingIsNeeded else {
                return
            }
            
            animatedFrames[previousFrameIndex] = animatedFrames[previousFrameIndex]?.placeholderFrame
            
            preloadIndexes(start: currentFrameIndex).forEach { index in
                guard let currentAnimatedFrame = animatedFrames[index] else { return }
                if !currentAnimatedFrame.isPlaceholder { return }
                animatedFrames[index] = currentAnimatedFrame.makeAnimatedFrame(image: loadFrame(at: index))
            }
        }
        
        private func incrementCurrentFrameIndex() {
            currentFrameIndex = increment(frameIndex: currentFrameIndex)
            if isLastFrame {
                currentRepeatCount += 1
                if isReachMaxRepeatCount {
                    isFinished = true
                }
                delegate?.animator(self, didPlayAnimationLoops: currentRepeatCount)
            }
        }
        
        private func incrementTimeSinceLastFrameChange(with duration: TimeInterval) {
            timeSinceLastFrameChange += min(maxTimeStep, duration)
        }
        
        private func resetTimeSinceLastFrameChange() {
            timeSinceLastFrameChange -= currentFrameDuration
        }
        
        private func increment(frameIndex: Int, by value: Int = 1) -> Int {
            return (frameIndex + value) % frameCount
        }
        
        private func preloadIndexes(start index: Int) -> [Int] {
            let nextIndex = increment(frameIndex: index)
            let lastIndex = increment(frameIndex: index, by: maxFrameCount)
            
            if lastIndex >= nextIndex {
                return [Int](nextIndex...lastIndex)
            } else {
                return [Int](nextIndex..<frameCount) + [Int](0...lastIndex)
            }
        }
    }
}


class SafeArray<Element> {
    
    private var array: Array<Element> = []
    private let lock = NSLock()
    
    subscript(index: Int) -> Element? {
        get {
            lock.lock()
            defer { lock.unlock() }
            // ~=
            return array.indices ~= index ? array[index] : nil
        }
        
        set {
            lock.lock()
            defer { lock.unlock() }
            if let newValue = newValue, array.indices ~= index {
                array[index] = newValue
            }
        }
    }
    
    var count : Int {
        lock.lock()
        defer { lock.unlock() }
        return array.count
    }
    
    func reserveCapacity(_ count: Int) {
        lock.lock()
        defer { lock.unlock() }
        array.reserveCapacity(count)
    }
    
    func append(_ element: Element) {
        lock.lock()
        defer { lock.unlock() }
        array += [element]
    }
    
    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        array = []
    }
}
#endif
#endif
