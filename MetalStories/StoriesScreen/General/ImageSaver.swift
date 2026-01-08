import CoreGraphics
import Foundation
import ImageIO
import Photos

enum ImageSaver {

    // MARK: Internal

    enum ImageSaverError: LocalizedError {
        case failedToCreateImageDestination
        case failedToFinalizeImageDestination
        case failedToSaveImage
        case photoLibraryAccessDenied

        var errorDescription: String? {
            switch self {
            case .failedToCreateImageDestination:
                "Unable to prepare the image for saving."
            case .failedToFinalizeImageDestination:
                "Unable to encode the image. Please try again."
            case .failedToSaveImage:
                "Unable to save the image to your photo library."
            case .photoLibraryAccessDenied:
                "Photo library access is required. Please enable it in Settings."
            }
        }
    }

    static func saveImage(
        _ cgImage: CGImage,
        newOrientation: CGImagePropertyOrientation,
        originalData: Data?,
        callbackQueue: DispatchQueue,
        completion: @escaping (Result<Void, Error>) -> Void,
    ) {
        let imageDataResult = makeImageData(
            cgImage,
            newOrientation: newOrientation,
            originalData: originalData,
        )

        let onCompletion: (Result<Void, Error>) -> Void = { result in
            callbackQueue.async {
                completion(result)
            }
        }

        switch imageDataResult {
        case .success(let result):
            requestPhotoLibraryAccess { accessResult in
                switch accessResult {
                case .success:
                    saveToPhotoLibrary(
                        imageData: result.data,
                        destinationTypeIdentifier: result.typeIdentifier,
                        completion: onCompletion,
                    )

                case .failure(let error):
                    onCompletion(.failure(error))
                }
            }

        case .failure(let error):
            onCompletion(.failure(error))
        }
    }

    // MARK: Private

    private static func getMetadata(
        from imageSource: CGImageSource?,
        newOrientation: CGImagePropertyOrientation,
    ) -> CFDictionary {
        var metadata = [CFString: Any]()
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
        originalData: Data?,
    ) -> Result<(data: Data, typeIdentifier: CFString), Error> {
        let imageSource = makeImageSource(from: originalData)

        let metadata = getMetadata(
            from: imageSource,
            newOrientation: newOrientation,
        )

        let destinationTypeIdentifier = getDestinationTypeIdentifier(from: imageSource)

        let imageData = NSMutableData()
        let destination = CGImageDestinationCreateWithData(
            imageData as CFMutableData,
            destinationTypeIdentifier,
            1,
            nil,
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
            completion(.failure(ImageSaverError.photoLibraryAccessDenied))
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
        completion: @escaping (Result<Void, Error>) -> Void,
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
