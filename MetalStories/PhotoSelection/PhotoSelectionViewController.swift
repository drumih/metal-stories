import PhotosUI
import UIKit

// MARK: - PhotoSelectionViewController

final class PhotoSelectionViewController: UIViewController {

    // MARK: Internal

    var presenter: PhotoSelectionPresenter!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

    // MARK: Private

    private lazy var selectPhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select Photo", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(selectPhotoTapped), for: .touchUpInside)
        return button
    }()

    private lazy var renderPassSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Simple", "Intermediate", "Tile"])
        control.addTarget(self, action: #selector(renderPassTypeChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private lazy var previousImageContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private lazy var previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var useCachedImageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Use Cached Image", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(loadPreviousImageTapped), for: .touchUpInside)
        return button
    }()

    
    private lazy var deleteCachedImageButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.backgroundColor = .systemRed
        button.tintColor = .white
        button.layer.cornerRadius = 15
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(deletePreviousImageTapped), for: .touchUpInside)
        return button
    }()

    private func setupUI() {
        view.backgroundColor = .systemBackground

        renderPassSegmentedControl.selectedSegmentIndex = presenter.selectedRenderPassType.rawValue

        previousImageContainerView.addSubview(previewImageView)
        previousImageContainerView.addSubview(deleteCachedImageButton)
        previousImageContainerView.addSubview(useCachedImageButton)

        view.addSubview(selectPhotoButton)
        view.addSubview(previousImageContainerView)
        view.addSubview(renderPassSegmentedControl)

        NSLayoutConstraint.activate([
            renderPassSegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            renderPassSegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            renderPassSegmentedControl.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -16
            ),

            selectPhotoButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            selectPhotoButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            selectPhotoButton.bottomAnchor.constraint(equalTo: renderPassSegmentedControl.topAnchor, constant: -16),
            selectPhotoButton.heightAnchor.constraint(equalToConstant: 50),

            previousImageContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            previousImageContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            previousImageContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            previousImageContainerView.bottomAnchor.constraint(equalTo: selectPhotoButton.topAnchor, constant: -16),

            previewImageView.topAnchor.constraint(equalTo: previousImageContainerView.topAnchor),
            previewImageView.leadingAnchor.constraint(equalTo: previousImageContainerView.leadingAnchor),
            previewImageView.trailingAnchor.constraint(equalTo: previousImageContainerView.trailingAnchor),
            previewImageView.bottomAnchor.constraint(equalTo: useCachedImageButton.topAnchor),

            useCachedImageButton.leadingAnchor.constraint(equalTo: previousImageContainerView.leadingAnchor),
            useCachedImageButton.trailingAnchor.constraint(equalTo: previousImageContainerView.trailingAnchor),
            useCachedImageButton.bottomAnchor.constraint(equalTo: previousImageContainerView.bottomAnchor),
            useCachedImageButton.heightAnchor.constraint(equalToConstant: 50),

            deleteCachedImageButton.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: 8),
            deleteCachedImageButton.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: -8),
            deleteCachedImageButton.widthAnchor.constraint(equalToConstant: 30),
            deleteCachedImageButton.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    @objc
    private func selectPhotoTapped() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc
    private func renderPassTypeChanged(_ sender: UISegmentedControl) {
        guard let renderPassType = RenderPassType(rawValue: sender.selectedSegmentIndex) else {
            assertionFailure()
            return
        }
        presenter.updateRenderPassType(renderPassType)
    }

    @objc
    private func loadPreviousImageTapped() {
        presenter.loadPreviousImage()
    }

    @objc
    private func deletePreviousImageTapped() {
        presenter.deleteSavedImage()
    }
}

// MARK: PhotoSelectionView

extension PhotoSelectionViewController: PhotoSelectionView {

    func updateState(_ cachedImage: UIImage?) {
        if let cachedImage {
            previewImageView.image = cachedImage
            previousImageContainerView.isHidden = false
        } else {
            previewImageView.image = nil
            previousImageContainerView.isHidden = true
        }
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
