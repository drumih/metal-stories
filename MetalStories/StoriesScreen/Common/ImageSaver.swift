import CoreGraphics
import Foundation
import ImageIO
import Photos
import UniformTypeIdentifiers

enum ImageSaver {
    
    // MARK: - ImageSaverError

    enum ImageSaverError: Error {
        case failedToCreateImageDestination
        case failedToFinalizeImageDestination
        case failedToSaveImage
    }
    
    static func saveImage(
        _ cgImage: CGImage,
        newOrientation: CGImagePropertyOrientation,
        originalData: Data?,
        completion: @escaping (Result<Void, Error>) -> Void,
    ) {
        
        let imageSource = makeImageSource(from: originalData)

        let metadata = getMetadata(
            from: imageSource,
            newOrientation: newOrientation
        )

        let destinationTypeIdentifier: CFString = {
            if let imageSource, let type = CGImageSourceGetType(imageSource) {
                return type
            } else {
                return UTType.heic.identifier as CFString
            }
        }()

        let imageData = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            imageData as CFMutableData,
            destinationTypeIdentifier,
            1,
            nil,
        )

        guard let destination else {
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
            options.uniformTypeIdentifier = destinationTypeIdentifier as String
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData as Data, options: options)
        } completionHandler: { success, error in
            if success {
                completion(.success(()))
            } else {
                completion(.failure(error ?? ImageSaverError.failedToSaveImage))
            }
        }
    }

    private static func getMetadata(
        from imageSource: CGImageSource?,
        newOrientation: CGImagePropertyOrientation,
    ) -> CFDictionary {
        var metadata: [CFString: Any] = [:]
        if let imageSource, let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
            metadata = properties
        }
        metadata[kCGImagePropertyOrientation] = newOrientation.rawValue
        
        return metadata as CFDictionary
    }

    private static func makeImageSource(from data: Data?) -> CGImageSource? {
        guard let data else { return nil }
        return CGImageSourceCreateWithData(data as CFData, nil)
    }
}
