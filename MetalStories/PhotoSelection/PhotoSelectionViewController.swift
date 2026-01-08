import PhotosUI
import UIKit

// MARK: - PhotoSelectionViewController


final class PhotoSelectionViewController: UIViewController {

    // MARK: Internal

    var presenter: PhotoSelectionPresenter!

    override func loadView() {
        view = PhotoSelectionView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

    private func setupUI() {
        contentView.configure(selectedRenderPassIndex: presenter.selectedRenderPassType.rawValue)
        contentView.delegate = self
    }

    private var contentView: PhotoSelectionView {
        guard let contentView = view as? PhotoSelectionView else {
            fatalError("PhotoSelectionViewController expects PhotoSelectionView")
        }
        return contentView
    }

    private func selectPhotoTapped() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    private func renderPassTypeChanged(selectedIndex: Int) {
        guard let renderPassType = RenderPassType(rawValue: selectedIndex) else {
            assertionFailure()
            return
        }
        presenter.updateRenderPassType(renderPassType)
    }

    private func loadPreviousImageTapped() {
        presenter.loadPreviousImage()
    }

    private func deletePreviousImageTapped() {
        presenter.deleteSavedImage()
    }
}

// MARK: PhotoSelectionView

extension PhotoSelectionViewController: PhotoSelectionViewProtocol {

    func updateState(_ cachedImage: UIImage?) {
        contentView.updateCachedImage(cachedImage)
    }

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

    func photoSelectionViewDidTapSelectPhoto(_ view: PhotoSelectionView) {
        selectPhotoTapped()
    }

    func photoSelectionView(_ view: PhotoSelectionView, didChangeRenderPassIndex index: Int) {
        renderPassTypeChanged(selectedIndex: index)
    }

    func photoSelectionViewDidTapUseCachedImage(_ view: PhotoSelectionView) {
        loadPreviousImageTapped()
    }

    func photoSelectionViewDidTapDeleteCachedImage(_ view: PhotoSelectionView) {
        deletePreviousImageTapped()
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
        presenter.didSelectImage(result)
    }
}
