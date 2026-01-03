import CoreGraphics
import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

// MARK: - ImageSaver

enum ImageSaver {
    static func saveImage(
        _ cgImage: CGImage,
        newOrientation: CGImagePropertyOrientation,
        originalData: Data?,
        completion: @escaping (Result<Void, Error>) -> Void,
    ) {
        var metadata: [CFString: Any] =
            if
                let originalData,
                let source = CGImageSourceCreateWithData(originalData as CFData, nil),
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
            {
                properties
            } else {
                [:]
            }
        metadata[kCGImagePropertyOrientation] = newOrientation.rawValue

        let imageData = NSMutableData()
        guard
            let destination = CGImageDestinationCreateWithData(
                imageData as CFMutableData,
                UTType.heic.identifier as CFString,
                1,
                nil,
            )
        else {
            completion(.failure(ImageSaverError.failedToCreateImageDestination))
            return
        }

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            completion(.failure(ImageSaverError.failedToFinalizeImageDestination))
            return
        }

        PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = UTType.heic.identifier
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData as Data, options: options)
        } completionHandler: { success, error in
            if success {
                completion(.success(()))
            } else {
                completion(.failure(error ?? ImageSaverError.failedToSaveImage))
            }
        }
    }
}

// MARK: - ImageSaverError

enum ImageSaverError: Error {
    case failedToCreateImageDestination
    case failedToFinalizeImageDestination
    case failedToSaveImage
}
