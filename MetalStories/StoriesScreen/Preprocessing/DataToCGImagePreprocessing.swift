import CoreGraphics
import Foundation
import ImageIO

// MARK: - DataToCGImagePreprocessing

enum DataToCGImagePreprocessing {
    static func loadCGImage(
        from data: Data
    ) throws -> (CGImage, CGImagePropertyOrientation) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImagePreprocessingError.failedToCreateImage
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

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw ImagePreprocessingError.failedToCreateImage
        }

        return (cgImage, orientation)
    }
}

// MARK: - ImagePreprocessingError

enum ImagePreprocessingError: LocalizedError {
    case failedToCreateImage
}

extension ImagePreprocessingError {

    var errorDescription: String? {
        switch self {
        case .failedToCreateImage:
            "Unable to create image from data. The file may be corrupted or in an unsupported format."
        }
    }
}
