import Foundation


// 从这里可以看出, 不同格式的 Image 其实数据的头信息, 是不一样的.
/// Represents image format.
///
/// - unknown: The format cannot be recognized or not supported yet.
/// - PNG: PNG image format.
/// - JPEG: JPEG image format.
/// - GIF: GIF image format.
public enum ImageFormat {
    /// The format cannot be recognized or not supported yet.
    case unknown
    /// PNG image format.
    case PNG
    /// JPEG image format.
    case JPEG
    /// GIF image format.
    case GIF
    
    
    // 顶级的类型, 只包含上面四个值, 但是在 ImageFormat 下面, 定义所使用的类型的数据.
    // 这些类型, 与其说是对象, 不如说是命名空间, 他们存在的意义, 就是一个特定的作用域, 包裹所对应的数据而已,
    struct HeaderData {
        static var PNG: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
        static var JPEG_SOI: [UInt8] = [0xFF, 0xD8]
        static var JPEG_IF: [UInt8] = [0xFF]
        static var GIF: [UInt8] = [0x47, 0x49, 0x46]
    }
    
    /// https://en.wikipedia.org/wiki/JPEG
    public enum JPEGMarker {
        case SOF0           //baseline
        case SOF2           //progressive
        case DHT            //Huffman Table
        case DQT            //Quantization Table
        case DRI            //Restart Interval
        case SOS            //Start Of Scan
        case RSTn(UInt8)    //Restart
        case APPn           //Application-specific
        case COM            //Comment
        case EOI            //End Of Image
        
        var bytes: [UInt8] {
            switch self {
            case .SOF0:         return [0xFF, 0xC0]
            case .SOF2:         return [0xFF, 0xC2]
            case .DHT:          return [0xFF, 0xC4]
            case .DQT:          return [0xFF, 0xDB]
            case .DRI:          return [0xFF, 0xDD]
            case .SOS:          return [0xFF, 0xDA]
            case .RSTn(let n):  return [0xFF, 0xD0 + n]
            case .APPn:         return [0xFF, 0xE0]
            case .COM:          return [0xFF, 0xFE]
            case .EOI:          return [0xFF, 0xD9]
            }
        }
    }
}


extension Data: KingfisherCompatibleValue {}

// MARK: - Misc Helpers
// 可以这样认为, 各种之前, 需要增加 kf_作为开头的分类方法, 都可以使用这种方法, 提供一个自定义领域的扩展点来, 使用 KingfisherWrapper 的条件编译, 来实现.

extension KingfisherWrapper where Base == Data {
    /// Gets the image format corresponding to the data.
    
    // 从这里可以看出, 判断图片的类型, 就是根据文件的头数据算出来的.
    // 所以其实这是个计算属性, 每次都是拿到 Data 的前面几个部分, 跟对应的值进行比较之后返回的结果. 
    public var imageFormat: ImageFormat {
        guard base.count > 8 else { return .unknown }
        
        var buffer = [UInt8](repeating: 0, count: 8)
        base.copyBytes(to: &buffer, count: 8)
        
        if buffer == ImageFormat.HeaderData.PNG {
            return .PNG
            
        } else if buffer[0] == ImageFormat.HeaderData.JPEG_SOI[0],
            buffer[1] == ImageFormat.HeaderData.JPEG_SOI[1],
            buffer[2] == ImageFormat.HeaderData.JPEG_IF[0]
        {
            return .JPEG
            
        } else if buffer[0] == ImageFormat.HeaderData.GIF[0],
            buffer[1] == ImageFormat.HeaderData.GIF[1],
            buffer[2] == ImageFormat.HeaderData.GIF[2]
        {
            return .GIF
        }
        
        return .unknown
    }
    
    // 这个方法, 不太明白作用
    public func contains(jpeg marker: ImageFormat.JPEGMarker) -> Bool {
        guard imageFormat == .JPEG else {
            return false
        }
        
        var buffer = [UInt8](repeating: 0, count: base.count)
        base.copyBytes(to: &buffer, count: base.count)
        for (index, item) in buffer.enumerated() {
            guard
                item == marker.bytes.first,
                buffer.count > index + 1,
                buffer[index + 1] == marker.bytes[1] else {
                continue
            }
            return true
        }
        return false
    }
}
