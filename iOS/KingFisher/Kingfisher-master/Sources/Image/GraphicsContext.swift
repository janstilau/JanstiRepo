#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

enum GraphicsContext {
    static func begin(size: CGSize, scale: CGFloat) {
        #if os(macOS)
        NSGraphicsContext.saveGraphicsState()
        #else
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        #endif
    }
    
    static func current(size: CGSize, scale: CGFloat, inverting: Bool, cgImage: CGImage?) -> CGContext? {
        #if os(macOS)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width),
            pixelsHigh: Int(size.height),
            bitsPerSample: cgImage?.bitsPerComponent ?? 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0) else
        {
            assertionFailure("[Kingfisher] Image representation cannot be created.")
            return nil
        }
        rep.size = size
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            assertionFailure("[Kingfisher] Image context cannot be created.")
            return nil
        }
        
        NSGraphicsContext.current = context
        return context.cgContext
        #else
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        if inverting { // If drawing a CGImage, we need to make context flipped.
            context.scaleBy(x: 1.0, y: -1.0)
            context.translateBy(x: 0, y: -size.height)
        }
        return context
        #endif
    }
    
    static func end() {
        #if os(macOS)
        NSGraphicsContext.restoreGraphicsState()
        #else
        UIGraphicsEndImageContext()
        #endif
    }
}

