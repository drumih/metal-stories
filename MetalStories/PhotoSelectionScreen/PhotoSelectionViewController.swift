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
        loadCachedImagePreview()
    }

    // MARK: Private

    private enum Constants {
        static let cachedImageFileName = "cached_image.dat"
    }

    private lazy var contentView: PhotoSelectionView = {
        let contentView = PhotoSelectionView()
        contentView.configure(selectedRenderPassIndex: selectedRenderPassType.rawValue)
        contentView.delegate = self
        return contentView
    }()

    private var selectedRenderPassType = RenderPassType.directWithDepth
    private var previewImage: UIImage?

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.overrideUserInterfaceStyle = .dark
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
        contentView.updateCachedImagePreview(previewImage)
    }

    private func getCachedImageURL() -> URL? {
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

    private func loadCachedImageData() -> Data? {
        guard
            let fileURL = getCachedImageURL(),
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }

    private func loadCachedImagePreview() {
        defer { updateViewState() }
        guard let imageData = loadCachedImageData() else {
            previewImage = nil
            return
        }
        previewImage = UIImage(data: imageData)
    }

    private func deleteCachedImage() {
        guard
            let fileURL = getCachedImageURL(),
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
                message: "Failed to delete cached image"
            )
        }
    }

    private func loadCachedImage() {
        guard let imageData = loadCachedImageData() else {
            showErrorAlert(message: "No cached image found.")
            return
        }
        presentStoriesEditor(
            imageData: imageData,
            renderPassType: selectedRenderPassType,
        )
    }

    private func didSelectImage(_ result: PHPickerResult) {
        showLoadingOverlay()
        result.itemProvider
            .loadDataRepresentation(
                forTypeIdentifier: UTType.image.identifier
            ) { [weak self] data, error in
                guard let self else { return }

                guard let data, error == nil else {
                    DispatchQueue.main.async {
                        self.hideLoadingOverlay()
                        self.showErrorAlert(message: "Failed to load image. Please try again.")
                    }
                    return
                }

                if let fileURL = getCachedImageURL() {
                    try? data.write(to: fileURL)
                }

                DispatchQueue.main.async {
                    self.hideLoadingOverlay()
                    self.presentStoriesEditor(
                        imageData: data,
                        renderPassType: self.selectedRenderPassType,
                    )
                }
            }
    }

    private func showLoadingOverlay() {
        contentView.showLoadingOverlay()
    }

    private func hideLoadingOverlay() {
        contentView.hideLoadingOverlay()
    }
}

// MARK: - Presentation

extension PhotoSelectionViewController {

    func presentStoriesEditor(imageData: Data, renderPassType: RenderPassType) {
        do {
            let storiesViewController = try StoriesViewControllerFactory.getViewController(
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
        loadCachedImage()
    }

    func photoSelectionViewDidTapDeleteCachedImage() {
        deleteCachedImage()
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
