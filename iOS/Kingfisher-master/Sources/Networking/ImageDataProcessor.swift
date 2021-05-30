
import Foundation

private let sharedProcessingQueue: CallbackQueue =
    .dispatch(DispatchQueue(label: "com.onevcat.Kingfisher.ImageDownloader.Process"))

// Handles image processing work on an own process queue.
class ImageDataProcessor {
    let data: Data
    let callbacks: [SessionDataTask.TaskCallback]
    let queue: CallbackQueue
    
    // Note: We have an optimization choice there, to reduce queue dispatch by checking callback
    // queue settings in each option...
    let onImageProcessed = Delegate<
        (Result<KFCrossPlatformImage, KingfisherError>, SessionDataTask.TaskCallback), Void>()
    
    // data, 图像的原始数据.
    // callbacks, 处理完图像数据之后的各种回调方法.
    // 初始化的时候, 仅仅是将这些数据存储起来了, process, 是将处理图像数据的方法, 添加到 queue 里面, 最终, 是调用存储在 callbacks 里面的各种方法, 去触发后续的操作.
    init(data: Data, callbacks: [SessionDataTask.TaskCallback], processingQueue: CallbackQueue?) {
        self.data = data
        self.callbacks = callbacks
        self.queue = processingQueue ?? sharedProcessingQueue
    }
    
    func process() {
        queue.execute(doProcess)
    }
    
    private func doProcess() {
        var processedImages = [String: KFCrossPlatformImage]()
        for callback in callbacks {
            let processor = callback.options.processor
            var image = processedImages[processor.identifier]
            if image == nil {
                image = processor.process(item: .data(data), options: callback.options)
                processedImages[processor.identifier] = image
            }
            
            let result: Result<KFCrossPlatformImage, KingfisherError>
            if let image = image {
                let finalImage = callback.options.backgroundDecode ? image.kf.decoded : image
                result = .success(finalImage)
            } else {
                let error = KingfisherError.processorError(
                    reason: .processingFailed(processor: processor, item: .data(data)))
                result = .failure(error)
            }
            onImageProcessed.call((result, callback))
        }
    }
}
