import PhotosUI
import UIKit

// MARK: - PhotoSelectionViewController

final class PhotoSelectionViewController: UIViewController {

    // MARK: Internal

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadSavedImagePreview()
    }

    // MARK: Private

    private enum Constants {
        static let cachedImageFileName = "cached_image.dat"
        static let previewMaxDimensionSize: CGFloat = 1080
    }

    private lazy var contentView: PhotoSelectionView = {
        let contentView = PhotoSelectionView()
        contentView.configure(selectedRenderPassIndex: selectedRenderPassType.rawValue)
        contentView.delegate = self
        return contentView
    }()

    private var selectedRenderPassType = RenderPassType.tileMemory
    private var previewImage: UIImage?

    private func setupUI() {
        view.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func selectPhoto() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func changeRenderPassType(to index: Int) {
        guard let renderPassType = RenderPassType(rawValue: index) else {
            assertionFailure()
            return
        }
        selectedRenderPassType = renderPassType
    }

    private func updateViewState() {
        contentView.updateCachedImage(previewImage)
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

    private func loadSavedImageData() -> Data? {
        guard
            let fileURL = getSavedImageURL(),
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
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

    private func deleteSavedImage() {
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
            showErrorAlert(
                message: "Failed to delete saved image"
            )
        }
    }

    private func loadPreviousImage() {
        guard let imageData = loadSavedImageData() else {
            showErrorAlert(message: "No saved image found.")
            return
        }
        presentStoriesEditor(
            imageData: imageData,
            renderPassType: selectedRenderPassType,
        )
    }

    private func didSelectImage(_ result: PHPickerResult) {
        result.itemProvider
            .loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { [weak self] data, error in
                guard let self else { return }

                guard let data, error == nil else {
                    DispatchQueue.main.async {
                        self.showErrorAlert(message: "Failed to load image. Please try again.")
                    }
                    return
                }

                if let fileURL = getSavedImageURL() {
                    try? data.write(to: fileURL)
                }

                DispatchQueue.main.async {
                    self.presentStoriesEditor(
                        imageData: data,
                        renderPassType: self.selectedRenderPassType,
                    )
                }
            }
    }
}

// MARK: PhotoSelectionView

extension PhotoSelectionViewController {

    func presentStoriesEditor(imageData: Data, renderPassType: RenderPassType) {
        do {
            let storiesViewController = try StoriesViewControllerFactor.getViewController(
                imageData: imageData,
                renderPassType: renderPassType,
            )
            storiesViewController.modalPresentationStyle = .fullScreen
            present(storiesViewController, animated: true)
        } catch {
            showErrorAlert(message: "Failed to create stories editor. Please try again.")
        }
    }

    func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: PhotoSelectionViewDelegate

extension PhotoSelectionViewController: PhotoSelectionViewDelegate {

    func photoSelectionViewDidTapSelectPhoto() {
        selectPhoto()
    }

    func photoSelectionView(didChangeRenderPassIndex index: Int) {
        changeRenderPassType(to: index)
    }

    func photoSelectionViewDidTapUseCachedImage() {
        loadPreviousImage()
    }

    func photoSelectionViewDidTapDeleteCachedImage() {
        deleteSavedImage()
    }
}

// MARK: PHPickerViewControllerDelegate

extension PhotoSelectionViewController: PHPickerViewControllerDelegate {

    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult],
    ) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        didSelectImage(result)
    }
}
