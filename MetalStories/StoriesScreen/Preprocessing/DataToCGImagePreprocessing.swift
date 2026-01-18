import CoreGraphics
import Foundation
import ImageIO

// MARK: - DataToCGImagePreprocessing

enum DataToCGImagePreprocessing {

    enum DataToCGImagePreprocessingError: LocalizedError {
        case failedToCreateImage
    }

    static func loadCGImage(
        from data: Data
    ) throws -> (CGImage, CGImagePropertyOrientation) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw DataToCGImagePreprocessingError.failedToCreateImage
        }

        let orientation: CGImagePropertyOrientation =
            if
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                let orientationValue = properties[kCGImagePropertyOrientation] as? UInt32,
                let targetOrientation = CGImagePropertyOrientation(rawValue: orientationValue)
            {
                targetOrientation
            } else {
                .up
            }

        guard let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw DataToCGImagePreprocessingError.failedToCreateImage
        }

        return (cgImage, orientation)
    }
}

// MARK: - DataToCGImagePreprocessingError

enum DataToCGImagePreprocessingError: LocalizedError {
    case failedToCreateImage
}

extension DataToCGImagePreprocessingError {

    var errorDescription: String? {
        switch self {
        case .failedToCreateImage:
            "Unable to create image from data. The file may be corrupted or in an unsupported format."
        }
    }
}
