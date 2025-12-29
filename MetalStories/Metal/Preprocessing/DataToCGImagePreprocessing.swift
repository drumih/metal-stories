import Foundation
import ImageIO
import CoreGraphics

enum DataToCGImagePreprocessing {
    static func loadCGImage(
        from data: Data,
        maxSize: CGSize
    ) throws -> (CGImage, CGImagePropertyOrientation) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImagePreprocessingError.failedToCreateImageSource
        }
        
        // Extract orientation from image properties
        let orientation: CGImagePropertyOrientation
        if let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
           let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32 {
            orientation = CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
        } else {
            orientation = .up
        }
        
        // Calculate max pixel size
        let maxPixelSize = max(maxSize.width, maxSize.height)
        
        // Create thumbnail options
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImagePreprocessingError.failedToCreateThumbnail
        }
        
        return (cgImage, orientation)
    }
}

enum ImagePreprocessingError: Error {
    case failedToCreateImageSource
    case failedToCreateThumbnail
}
