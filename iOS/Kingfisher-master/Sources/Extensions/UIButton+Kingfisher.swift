#if !os(watchOS)

#if canImport(UIKit)
import UIKit

extension KingfisherWrapper where Base: UIButton {

    // MARK: Setting Image
    /// Sets an image to the button for a specified state with a source.
    ///
    /// - Parameters:
    ///   - source: The `Source` object contains information about the image.
    ///   - state: The button state to which the image should be set.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `KingfisherOptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested source, from either cache
    /// or network. Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setImage(
        with source: Source?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        let options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions + (options ?? .empty))
        return setImage(
            with: source,
            for: state,
            placeholder: placeholder,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler
        )
    }
    
    /// Sets an image to the button for a specified state with a requested resource.
    ///
    /// - Parameters:
    ///   - resource: The `Resource` object contains information about the resource.
    ///   - state: The button state to which the image should be set.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `KingfisherOptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested resource, from either cache
    /// or network. Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setImage(
        with resource: Resource?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        return setImage(
            with: resource?.convertToSource(),
            for: state,
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    // 这里做的事情, 没有太大的区别和 ImageView . 仅仅是设置 image 的时候, 有了 state 的判断.
    @discardableResult
    public func setImage(
        with source: Source?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        parsedOptions: KingfisherParsedOptionsInfo,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        guard let source = source else {
            base.setImage(placeholder, for: state)
            setTaskIdentifier(nil, for: state)
            completionHandler?(.failure(KingfisherError.imageSettingError(reason: .emptySource)))
            return nil
        }

        var options = parsedOptions
        if !options.keepCurrentImageWhileLoading {
            base.setImage(placeholder, for: state)
        }

        var mutatingSelf = self
        let issuedIdentifier = Source.Identifier.next()
        setTaskIdentifier(issuedIdentifier, for: state)

        if let block = progressBlock {
            options.onDataReceived = (options.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }

        if let provider = ImageProgressiveProvider(options, refresh: { image in
            self.base.setImage(image, for: state)
        }) {
            options.onDataReceived = (options.onDataReceived ?? []) + [provider]
        }

        options.onDataReceived?.forEach {
            $0.onShouldApply = { issuedIdentifier == self.taskIdentifier(for: state) }
        }

        let task = KingfisherManager.shared.retrieveImage(
            with: source,
            options: options,
            downloadTaskUpdated: { mutatingSelf.imageTask = $0 },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedIdentifier == self.taskIdentifier(for: state) else {
                        let reason: KingfisherError.ImageSettingErrorReason
                        do {
                            let value = try result.get()
                            reason = .notCurrentSourceTask(result: value, error: nil, source: source)
                        } catch {
                            reason = .notCurrentSourceTask(result: nil, error: error, source: source)
                        }
                        let error = KingfisherError.imageSettingError(reason: reason)
                        completionHandler?(.failure(error))
                        return
                    }

                    mutatingSelf.imageTask = nil
                    mutatingSelf.setTaskIdentifier(nil, for: state)

                    switch result {
                    case .success(let value):
                        self.base.setImage(value.image, for: state)
                        completionHandler?(result)

                    case .failure:
                        if let image = options.onFailureImage {
                            self.base.setImage(image, for: state)
                        }
                        completionHandler?(result)
                    }
                }
            }
        )

        mutatingSelf.imageTask = task
        return task
    }

    // MARK: Cancelling Downloading Task
    
    /// Cancels the image download task of the button if it is running.
    /// Nothing will happen if the downloading has already finished.
    public func cancelImageDownloadTask() {
        imageTask?.cancel()
    }

    // MARK: Setting Background Image

    /// Sets a background image to the button for a specified state with a source.
    ///
    /// - Parameters:
    ///   - source: The `Source` object contains information about the image.
    ///   - state: The button state to which the image should be set.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `KingfisherOptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested source
    /// Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setBackgroundImage(
        with source: Source?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        let options = KingfisherParsedOptionsInfo(KingfisherManager.shared.defaultOptions + (options ?? .empty))
        return setBackgroundImage(
            with: source,
            for: state,
            placeholder: placeholder,
            parsedOptions: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler
        )
    }

    /// Sets a background image to the button for a specified state with a requested resource.
    ///
    /// - Parameters:
    ///   - resource: The `Resource` object contains information about the resource.
    ///   - state: The button state to which the image should be set.
    ///   - placeholder: A placeholder to show while retrieving the image from the given `resource`.
    ///   - options: An options set to define image setting behaviors. See `KingfisherOptionsInfo` for more.
    ///   - progressBlock: Called when the image downloading progress gets updated. If the response does not contain an
    ///                    `expectedContentLength`, this block will not be called.
    ///   - completionHandler: Called when the image retrieved and set finished.
    /// - Returns: A task represents the image downloading.
    ///
    /// - Note:
    /// Internally, this method will use `KingfisherManager` to get the requested resource, from either cache
    /// or network. Since this method will perform UI changes, you must call it from the main thread.
    /// Both `progressBlock` and `completionHandler` will be also executed in the main thread.
    ///
    @discardableResult
    public func setBackgroundImage(
        with resource: Resource?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        options: KingfisherOptionsInfo? = nil,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        return setBackgroundImage(
            with: resource?.convertToSource(),
            for: state,
            placeholder: placeholder,
            options: options,
            progressBlock: progressBlock,
            completionHandler: completionHandler)
    }

    func setBackgroundImage(
        with source: Source?,
        for state: UIControl.State,
        placeholder: UIImage? = nil,
        parsedOptions: KingfisherParsedOptionsInfo,
        progressBlock: DownloadProgressBlock? = nil,
        completionHandler: ((Result<RetrieveImageResult, KingfisherError>) -> Void)? = nil) -> DownloadTask?
    {
        guard let source = source else {
            base.setBackgroundImage(placeholder, for: state)
            setBackgroundTaskIdentifier(nil, for: state)
            completionHandler?(.failure(KingfisherError.imageSettingError(reason: .emptySource)))
            return nil
        }

        var options = parsedOptions
        if !options.keepCurrentImageWhileLoading {
            base.setBackgroundImage(placeholder, for: state)
        }

        var mutatingSelf = self
        let issuedIdentifier = Source.Identifier.next()
        setBackgroundTaskIdentifier(issuedIdentifier, for: state)

        if let block = progressBlock {
            options.onDataReceived = (options.onDataReceived ?? []) + [ImageLoadingProgressSideEffect(block)]
        }

        if let provider = ImageProgressiveProvider(options, refresh: { image in
            self.base.setBackgroundImage(image, for: state)
        }) {
            options.onDataReceived = (options.onDataReceived ?? []) + [provider]
        }

        options.onDataReceived?.forEach {
            $0.onShouldApply = { issuedIdentifier == self.backgroundTaskIdentifier(for: state) }
        }

        let task = KingfisherManager.shared.retrieveImage(
            with: source,
            options: options,
            downloadTaskUpdated: { mutatingSelf.backgroundImageTask = $0 },
            completionHandler: { result in
                CallbackQueue.mainCurrentOrAsync.execute {
                    guard issuedIdentifier == self.backgroundTaskIdentifier(for: state) else {
                        let reason: KingfisherError.ImageSettingErrorReason
                        do {
                            let value = try result.get()
                            reason = .notCurrentSourceTask(result: value, error: nil, source: source)
                        } catch {
                            reason = .notCurrentSourceTask(result: nil, error: error, source: source)
                        }
                        let error = KingfisherError.imageSettingError(reason: reason)
                        completionHandler?(.failure(error))
                        return
                    }

                    mutatingSelf.backgroundImageTask = nil
                    mutatingSelf.setBackgroundTaskIdentifier(nil, for: state)

                    switch result {
                    case .success(let value):
                        self.base.setBackgroundImage(value.image, for: state)
                        completionHandler?(result)

                    case .failure:
                        if let image = options.onFailureImage {
                            self.base.setBackgroundImage(image, for: state)
                        }
                        completionHandler?(result)
                    }
                }
            }
        )

        mutatingSelf.backgroundImageTask = task
        return task
    }

    // MARK: Cancelling Background Downloading Task
    
    /// Cancels the background image download task of the button if it is running.
    /// Nothing will happen if the downloading has already finished.
    public func cancelBackgroundImageDownloadTask() {
        backgroundImageTask?.cancel()
    }
}

// MARK: - Associated Object
private var taskIdentifierKey: Void?
private var imageTaskKey: Void?

// MARK: Properties
extension KingfisherWrapper where Base: UIButton {

    private typealias TaskIdentifier = Box<[UInt: Source.Identifier.Value]>
    
    public func taskIdentifier(for state: UIControl.State) -> Source.Identifier.Value? {
        return taskIdentifierInfo.value[state.rawValue]
    }

    private func setTaskIdentifier(_ identifier: Source.Identifier.Value?, for state: UIControl.State) {
        taskIdentifierInfo.value[state.rawValue] = identifier
    }
    
    private var taskIdentifierInfo: TaskIdentifier {
        return  getAssociatedObject(base, &taskIdentifierKey) ?? {
            setRetainedAssociatedObject(base, &taskIdentifierKey, $0)
            return $0
        } (TaskIdentifier([:]))
    }
    
    private var imageTask: DownloadTask? {
        get { return getAssociatedObject(base, &imageTaskKey) }
        set { setRetainedAssociatedObject(base, &imageTaskKey, newValue)}
    }
}


private var backgroundTaskIdentifierKey: Void?
private var backgroundImageTaskKey: Void?

// MARK: Background Properties
extension KingfisherWrapper where Base: UIButton {
    
    public func backgroundTaskIdentifier(for state: UIControl.State) -> Source.Identifier.Value? {
        return backgroundTaskIdentifierInfo.value[state.rawValue]
    }
    
    private func setBackgroundTaskIdentifier(_ identifier: Source.Identifier.Value?, for state: UIControl.State) {
        backgroundTaskIdentifierInfo.value[state.rawValue] = identifier
    }
    
    private var backgroundTaskIdentifierInfo: TaskIdentifier {
        return  getAssociatedObject(base, &backgroundTaskIdentifierKey) ?? {
            setRetainedAssociatedObject(base, &backgroundTaskIdentifierKey, $0)
            return $0
        } (TaskIdentifier([:]))
    }
    
    private var backgroundImageTask: DownloadTask? {
        get { return getAssociatedObject(base, &backgroundImageTaskKey) }
        mutating set { setRetainedAssociatedObject(base, &backgroundImageTaskKey, newValue) }
    }
}
#endif

#endif
