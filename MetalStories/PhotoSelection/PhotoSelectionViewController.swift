import UIKit
import PhotosUI

final class PhotoSelectionViewController: UIViewController {

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
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.cornerCurve = .continuous
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

    var presenter: PhotoSelectionPresenter!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presenter.viewWillAppear()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground

        renderPassSegmentedControl.selectedSegmentIndex = presenter.selectedRenderPassType.rawValue

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

            // Preview image
            previewImageView.topAnchor.constraint(equalTo: previousImageContainerView.topAnchor),
            previewImageView.centerXAnchor.constraint(equalTo: previousImageContainerView.centerXAnchor),
            previewImageView.widthAnchor.constraint(equalToConstant: 300),
            previewImageView.heightAnchor.constraint(equalToConstant: 300),

            deletePreviousButton.topAnchor.constraint(equalTo: previewImageView.topAnchor, constant: -5),
            deletePreviousButton.trailingAnchor.constraint(equalTo: previewImageView.trailingAnchor, constant: 5),
            deletePreviousButton.widthAnchor.constraint(equalToConstant: 30),
            deletePreviousButton.heightAnchor.constraint(equalToConstant: 30),

            loadPreviousButton.topAnchor.constraint(equalTo: previewImageView.bottomAnchor, constant: 16),
            loadPreviousButton.centerXAnchor.constraint(equalTo: previousImageContainerView.centerXAnchor),
            loadPreviousButton.widthAnchor.constraint(equalToConstant: 200),
            loadPreviousButton.heightAnchor.constraint(equalToConstant: 44),
            loadPreviousButton.bottomAnchor.constraint(equalTo: previousImageContainerView.bottomAnchor)
        ])
    }

    @objc
    private func accessSwitchChanged(_ sender: UISwitch) {
        if sender.isOn {
            presenter.requestGalleryAccess()
        }
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
    private func openSettingsTapped() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
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

extension PhotoSelectionViewController: PhotoSelectionView {

    func updateState(_ state: PhotoSelectionViewState) {
        switch state {
        case .authorized(let previewImage):
            accessStackView.isHidden = true
            selectPhotoButton.isHidden = false
            openSettingsButton.isHidden = true
            renderPassSegmentedControl.isHidden = false

            if let previewImage = previewImage {
                previewImageView.image = previewImage
                previousImageContainerView.isHidden = false
            } else {
                previewImageView.image = nil
                previousImageContainerView.isHidden = true
            }

        case .denied:
            accessStackView.isHidden = true
            selectPhotoButton.isHidden = true
            openSettingsButton.isHidden = false
            renderPassSegmentedControl.isHidden = true
            previousImageContainerView.isHidden = true

        case .notDetermined:
            accessStackView.isHidden = false
            accessSwitch.isOn = false
            selectPhotoButton.isHidden = true
            openSettingsButton.isHidden = true
            renderPassSegmentedControl.isHidden = true
            previousImageContainerView.isHidden = true
        }
    }

    func presentStoriesEditor(imageData: Data, renderPassType: RenderPassType) {
        do {
            let storiesViewController = try StoriesViewControllerFactor.getViewController(
                imageData: imageData,
                renderPassType: renderPassType
            )
            let navigationController = UINavigationController(rootViewController: storiesViewController)
            navigationController.modalPresentationStyle = .fullScreen
            present(navigationController, animated: true)
        } catch {
            showErrorAlert(message: "Failed to create stories editor. Please try again.")
        }
    }

    func showErrorAlert(message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension PhotoSelectionViewController: PHPickerViewControllerDelegate {

    func picker(
        _ picker: PHPickerViewController,
        didFinishPicking results: [PHPickerResult]
    ) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        presenter.didSelectImage(result)
    }
}
