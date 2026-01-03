import UIKit
import Photos
import PhotosUI
import UniformTypeIdentifiers

enum PhotoSelectionViewState {
    case authorized(previewImage: UIImage?)
    case denied
    case notDetermined
}

protocol PhotoSelectionView: AnyObject {
    func updateState(_ state: PhotoSelectionViewState)
    func presentStoriesEditor(imageData: Data, renderPassType: RenderPassType)
    func showErrorAlert(message: String)
}

final class PhotoSelectionPresenter {

    private enum Constants {
        static let cachedImageFileName = "cached_image.dat"
        static let previewMaxDimensionSize: CGFloat = 1080
    }

    private weak var view: PhotoSelectionView?
    private(set) var selectedRenderPassType: RenderPassType = .tileMemory
    private var previewImage: UIImage?

    init(view: PhotoSelectionView) {
        self.view = view
    }

    func viewWillAppear() {
        loadSavedImagePreview()
    }

    func requestGalleryAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateViewState()
            }
        }
    }

    private func updateViewState() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            view?.updateState(.authorized(previewImage: self.previewImage))
        case .denied, .restricted:
            view?.updateState(.denied)
        case .notDetermined:
            view?.updateState(.notDetermined)
        @unknown default:
            break
        }
    }

    func updateRenderPassType(_ type: RenderPassType) {
        selectedRenderPassType = type
    }
    
    func didSelectImage(_ result: PHPickerResult) {
        result.itemProvider
            .loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { [weak self] data, error in
            guard let self = self else { return }

            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self.view?.showErrorAlert(message: "Failed to load image. Please try again.")
                }
                return
            }
                
            if let fileURL = getSavedImageURL() {
                try? data.write(to: fileURL)
            }

            DispatchQueue.main.async {
                self.view?.presentStoriesEditor(
                    imageData: data,
                    renderPassType: self.selectedRenderPassType
                )
            }
        }
    }

    private func getSavedImageURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(
            Constants.cachedImageFileName
        )
    }

    private func cacheImageData(_ data: Data) {
        guard let fileURL = getSavedImageURL() else { return }
        do {
            try data.write(to: fileURL)
            loadSavedImagePreview()
        } catch {
            print("Failed to save image data: \(error)")
        }
    }

    func loadSavedImageData() -> Data? {
        guard
            let fileURL = getSavedImageURL(),
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }

    func deleteSavedImage() {
        guard let fileURL = getSavedImageURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: fileURL)
            previewImage = nil
            updateViewState()
        } catch {
            view?.showErrorAlert(
                message: "Failed to delete saved image"
            )
        }
    }

    private func loadSavedImagePreview() {
        defer { updateViewState() }
        guard let imageData = loadSavedImageData() else {
            previewImage = nil
            return
        }

        do {
            let (cgImage, _) = try DataToCGImagePreprocessing.loadCGImage(
                from: imageData,
                maxPixelSize: Constants.previewMaxDimensionSize
            )
            previewImage = UIImage(cgImage: cgImage)
        } catch {
            previewImage = nil
        }
    }

    func loadPreviousImage() {
        guard let imageData = loadSavedImageData() else {
            view?.showErrorAlert(message: "No saved image found.")
            return
        }
        view?.presentStoriesEditor(
            imageData: imageData,
            renderPassType: selectedRenderPassType
        )
    }
}
