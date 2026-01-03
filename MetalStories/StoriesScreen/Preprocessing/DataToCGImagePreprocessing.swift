import CoreGraphics
import Foundation
import ImageIO

// MARK: - DataToCGImagePreprocessing

enum DataToCGImagePreprocessing {
    static func loadCGImage(
        from data: Data,
        maxPixelSize: CGFloat,
    ) throws -> (CGImage, CGImagePropertyOrientation) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImagePreprocessingError.failedToCreateImageSource
        }

        let orientation: CGImagePropertyOrientation =
            if
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32
            {
                CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
            } else {
                .up
            }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ImagePreprocessingError.failedToCreateThumbnail
        }

        return (cgImage, orientation)
    }
}

// MARK: - ImagePreprocessingError

enum ImagePreprocessingError: Error {
    case failedToCreateImageSource
    case failedToCreateThumbnail
}
