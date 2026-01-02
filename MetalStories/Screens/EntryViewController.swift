import UIKit
import Photos
import PhotosUI
import UniformTypeIdentifiers

final class EntryViewController: UIViewController {

    // MARK: - Constants

    private enum Constants {
        static let savedImageFileName = "saved_image.dat"
        static let previewMaxSize = CGSize(width: 1080, height: 1080)
    }

    // MARK: - UI Elements

    private lazy var accessStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private lazy var accessLabel: UILabel = {
        let label = UILabel()
        label.text = "Allow gallery access"
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .label
        return label
    }()

    private lazy var accessSwitch: UISwitch = {
        let toggle = UISwitch()
        toggle.addTarget(self, action: #selector(accessSwitchChanged), for: .valueChanged)
        return toggle
    }()

    private lazy var selectPhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select Photo", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(selectPhotoTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private lazy var openSettingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Open Settings", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemGray
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)
        button.isHidden = true
        return button
    }()

    private lazy var renderPassSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Simple", "Intermediate"])
        control.addTarget(self, action: #selector(renderPassTypeChanged), for: .valueChanged)
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private var selectedRenderPassType: RenderPassType = .withIntermediateTexture {
        didSet {
            renderPassSegmentedControl.selectedSegmentIndex = selectedRenderPassType == .simple ? 0 : 1
        }
    }

    // MARK: - Previous Image UI Elements

    private lazy var previousImageContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private lazy var previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.borderWidth = 2
        imageView.layer.borderColor = UIColor.systemGray4.cgColor
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var loadPreviousButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Use Image", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(loadPreviousImageTapped), for: .touchUpInside)
        return button
    }()

    private lazy var deletePreviousButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .systemRed
        button.backgroundColor = .systemBackground
        button.layer.cornerRadius = 15
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(deletePreviousImageTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkGalleryAccess()
        loadSavedImagePreview()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkGalleryAccess()
        loadSavedImagePreview()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        renderPassSegmentedControl.selectedSegmentIndex = selectedRenderPassType == .simple ? 0 : 1

        accessStackView.addArrangedSubview(accessLabel)
        accessStackView.addArrangedSubview(accessSwitch)

        previousImageContainerView.addSubview(previewImageView)
        previousImageContainerView.addSubview(deletePreviousButton)
        previousImageContainerView.addSubview(loadPreviousButton)

        view.addSubview(accessStackView)
        view.addSubview(selectPhotoButton)
        view.addSubview(openSettingsButton)
        view.addSubview(previousImageContainerView)
        view.addSubview(renderPassSegmentedControl)

        NSLayoutConstraint.activate([
            accessStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            accessStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            selectPhotoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selectPhotoButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            selectPhotoButton.widthAnchor.constraint(equalToConstant: 200),
            selectPhotoButton.heightAnchor.constraint(equalToConstant: 50),

            openSettingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openSettingsButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            openSettingsButton.widthAnchor.constraint(equalToConstant: 200),
            openSettingsButton.heightAnchor.constraint(equalToConstant: 50),

            renderPassSegmentedControl.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            renderPassSegmentedControl.bottomAnchor.constraint(equalTo: selectPhotoButton.topAnchor, constant: -16),

            // Previous image container
            previousImageContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previousImageContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            previousImageContainerView.widthAnchor.constraint(equalToConstant: 320),
            previousImageContainerView.bottomAnchor.constraint(lessThanOrEqualTo: renderPassSegmentedControl.topAnchor, constant: -20),

            // Preview image - bigger
            previewImageView.topAnchor.constraint(equalTo: previousImageContainerView.topAnchor),
            previewImageView.centerXAnchor.constraint(equalTo: previousImageContainerView.centerXAnchor),
            previewImageView.widthAnchor.constraint(equalToConstant: 300),
            previewImageView.heightAnchor.constraint(equalToConstant: 300),

            // Delete button - top right of preview (positioned slightly outside)
            deletePreviousButton.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: -5),
            deletePreviousButton.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: 5),
            deletePreviousButton.widthAnchor.constraint(equalToConstant: 30),
            deletePreviousButton.heightAnchor.constraint(equalToConstant: 30),

            // Load button
            loadPreviousButton.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 16),
            loadPreviousButton.centerXAnchor.constraint(equalTo: previousImageContainerView.centerXAnchor),
            loadPreviousButton.widthAnchor.constraint(equalToConstant: 200),
            loadPreviousButton.heightAnchor.constraint(equalToConstant: 44),
            loadPreviousButton.bottomAnchor.constraint(equalTo: previousImageContainerView.bottomAnchor)
        ])
    }

    // MARK: - Gallery Access

    private func checkGalleryAccess() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        updateUI(for: status)
    }

    private func updateUI(for status: PHAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            switch status {
            case .authorized, .limited:
                self.accessStackView.isHidden = true
                self.selectPhotoButton.isHidden = false
                self.openSettingsButton.isHidden = true
                self.renderPassSegmentedControl.isHidden = false

            case .denied, .restricted:
                self.accessStackView.isHidden = true
                self.selectPhotoButton.isHidden = true
                self.openSettingsButton.isHidden = false
                self.renderPassSegmentedControl.isHidden = true

            case .notDetermined:
                self.accessStackView.isHidden = false
                self.accessSwitch.isOn = false
                self.selectPhotoButton.isHidden = true
                self.openSettingsButton.isHidden = true
                self.renderPassSegmentedControl.isHidden = true

            @unknown default:
                break
            }
        }
    }

    private func requestGalleryAccess() {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            self?.updateUI(for: status)
        }
    }

    // MARK: - Image Persistence

    private func getSavedImageURL() -> URL? {
        guard let documentsDirectory = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(Constants.savedImageFileName)
    }

    private func saveImageData(_ data: Data) {
        guard let fileURL = getSavedImageURL() else { return }
        do {
            try data.write(to: fileURL)
            loadSavedImagePreview()
        } catch {
            print("Failed to save image data: \(error)")
        }
    }

    private func loadSavedImageData() -> Data? {
        guard let fileURL = getSavedImageURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return try? Data(contentsOf: fileURL)
    }

    private func deleteSavedImage() {
        guard let fileURL = getSavedImageURL(),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: fileURL)
            updatePreviousImageUI(hasImage: false)
        } catch {
            print("Failed to delete saved image: \(error)")
        }
    }

    private func loadSavedImagePreview() {
        guard let imageData = loadSavedImageData() else {
            updatePreviousImageUI(hasImage: false)
            return
        }

        do {
            let (cgImage, _) = try DataToCGImagePreprocessing.loadCGImage(
                from: imageData,
                maxSize: Constants.previewMaxSize
            )
            let previewImage = UIImage(cgImage: cgImage)
            DispatchQueue.main.async { [weak self] in
                self?.previewImageView.image = previewImage
                self?.updatePreviousImageUI(hasImage: true)
            }
        } catch {
            print("Failed to create preview: \(error)")
            updatePreviousImageUI(hasImage: false)
        }
    }

    private func updatePreviousImageUI(hasImage: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.previousImageContainerView.isHidden = !hasImage
            self?.previewImageView.image = hasImage ? self?.previewImageView.image : nil
        }
    }

    // MARK: - Actions

    @objc private func accessSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            requestGalleryAccess()
        }
    }

    @objc private func selectPhotoTapped() {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }

    @objc private func openSettingsTapped() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }

    @objc private func renderPassTypeChanged(_ sender: UISegmentedControl) {
        selectedRenderPassType = sender.selectedSegmentIndex == 0 ? .simple : .withIntermediateTexture
    }

    @objc private func loadPreviousImageTapped() {
        guard let imageData = loadSavedImageData() else {
            showErrorAlert(message: "No saved image found.")
            return
        }
        presentStoriesEditor(withImageData: imageData)
    }

    @objc private func deletePreviousImageTapped() {
        deleteSavedImage()
    }
}

// MARK: - PHPickerViewControllerDelegate

extension EntryViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }

        result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { [weak self] data, error in
            guard let data = data, error == nil else {
                DispatchQueue.main.async {
                    self?.showErrorAlert(message: "Failed to load image. Please try again.")
                }
                return
            }
            
            // Save image data to disk for future use
            self?.saveImageData(data)
            
            DispatchQueue.main.async {
                self?.presentStoriesEditor(withImageData: data)
            }
        }
    }

    private func presentStoriesEditor(withImageData imageData: Data) {
        do {
            let storiesViewController = try StoriesViewControllerFactor.getViewController(
                imageData: imageData,
                renderPassType: selectedRenderPassType
            )
            let navigationController = UINavigationController(rootViewController: storiesViewController)
            navigationController.modalPresentationStyle = .fullScreen
            present(navigationController, animated: true)
        } catch {
            showErrorAlert(message: "Failed to create stories editor. Please try again.")
        }
    }
    
    private func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
