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
        let imageDataResult = makeImageData(
            cgImage,
            newOrientation: newOrientation,
            originalData: originalData
        )
        switch imageDataResult {
        case let .success(result):
            requestPhotoLibraryAccess { accessResult in
                switch accessResult {
                case .success:
                    saveToPhotoLibrary(
                        imageData: result.data,
                        destinationTypeIdentifier: result.typeIdentifier,
                        completion: completion
                    )
                case let .failure(error):
                    completion(.failure(error))
                }
            }
        case let .failure(error):
            completion(.failure(error))
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

    private static func getDestinationTypeIdentifier(from imageSource: CGImageSource?) -> CFString {
        if let imageSource, let type = CGImageSourceGetType(imageSource) {
            let heicIdentifier = UTType.heic.identifier as CFString
            if type == heicIdentifier {
                return heicIdentifier
            }
        }
        return UTType.jpeg.identifier as CFString
    }

    private static func makeImageSource(from data: Data?) -> CGImageSource? {
        guard let data else { return nil }
        return CGImageSourceCreateWithData(data as CFData, nil)
    }

    private static func makeImageData(
        _ cgImage: CGImage,
        newOrientation: CGImagePropertyOrientation,
        originalData: Data?
    ) -> Result<(data: Data, typeIdentifier: CFString), Error> {
        let imageSource = makeImageSource(from: originalData)

        let metadata = getMetadata(
            from: imageSource,
            newOrientation: newOrientation
        )

        let destinationTypeIdentifier = getDestinationTypeIdentifier(from: imageSource)

        let imageData = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            imageData as CFMutableData,
            destinationTypeIdentifier,
            1,
            nil
        )

        guard let destination else {
            return .failure(ImageSaverError.failedToCreateImageDestination)
        }

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return .failure(ImageSaverError.failedToFinalizeImageDestination)
        }

        return .success((data: imageData as Data, typeIdentifier: destinationTypeIdentifier))
    }

    private static func requestPhotoLibraryAccess(
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let currentStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        if currentStatus == .authorized || currentStatus == .limited {
            completion(.success(()))
            return
        }

        guard currentStatus == .notDetermined else {
            completion(.failure(ImageSaverError.failedToSaveImage))
            return
        }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            if status == .authorized || status == .limited {
                completion(.success(()))
            } else {
                completion(.failure(ImageSaverError.failedToSaveImage))
            }
        }
    }

    private static func saveToPhotoLibrary(
        imageData: Data,
        destinationTypeIdentifier: CFString,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        PHPhotoLibrary.shared().performChanges {
            let options = PHAssetResourceCreationOptions()
            options.uniformTypeIdentifier = destinationTypeIdentifier as String
            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: imageData, options: options)
        } completionHandler: { success, error in
            if success {
                completion(.success(()))
            } else {
                completion(.failure(error ?? ImageSaverError.failedToSaveImage))
            }
        }
    }
}
