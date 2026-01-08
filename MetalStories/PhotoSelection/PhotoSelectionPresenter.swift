import PhotosUI
import UIKit
import UniformTypeIdentifiers

// MARK: - PhotoSelectionView

protocol PhotoSelectionViewProtocol: AnyObject {
    func updateState(_ cachedImage: UIImage?)
    func presentStoriesEditor(imageData: Data, renderPassType: RenderPassType)
    func showErrorAlert(message: String)
}

// MARK: - PhotoSelectionPresenter

final class PhotoSelectionPresenter {

    // MARK: Lifecycle

    init(view: PhotoSelectionViewProtocol) {
        self.view = view
    }

    // MARK: Internal

    private(set) var selectedRenderPassType = RenderPassType.tileMemory

    func viewWillAppear() {
        loadSavedImagePreview()
    }

    func updateRenderPassType(_ type: RenderPassType) {
        selectedRenderPassType = type
    }

    func didSelectImage(_ result: PHPickerResult) {
        result.itemProvider
            .loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { [weak self] data, error in
                guard let self else { return }

                guard let data, error == nil else {
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
                        renderPassType: self.selectedRenderPassType,
                    )
                }
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
        guard
            let fileURL = getSavedImageURL(),
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
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

    func loadPreviousImage() {
        guard let imageData = loadSavedImageData() else {
            view?.showErrorAlert(message: "No saved image found.")
            return
        }
        view?.presentStoriesEditor(
            imageData: imageData,
            renderPassType: selectedRenderPassType,
        )
    }

    // MARK: Private

    private enum Constants {
        static let cachedImageFileName = "cached_image.dat"
        static let previewMaxDimensionSize: CGFloat = 1080
    }

    private weak var view: PhotoSelectionViewProtocol?
    private var previewImage: UIImage?

    private func updateViewState() {
        view?.updateState(previewImage)
    }

    private func getSavedImageURL() -> URL? {
        guard
            let documentsDirectory = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask,
            ).first
        else {
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

    private func loadSavedImagePreview() {
        defer { updateViewState() }
        guard let imageData = loadSavedImageData() else {
            previewImage = nil
            return
        }

        do {
            let (cgImage, _) = try DataToCGImagePreprocessing.loadCGImage(
                from: imageData,
                maxPixelSize: Constants.previewMaxDimensionSize,
            )
            previewImage = UIImage(cgImage: cgImage)
        } catch {
            previewImage = nil
        }
    }

}
