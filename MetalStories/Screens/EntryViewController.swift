import UIKit
import Photos
import PhotosUI

class EntryViewController: UIViewController {

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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkGalleryAccess()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        checkGalleryAccess()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        accessStackView.addArrangedSubview(accessLabel)
        accessStackView.addArrangedSubview(accessSwitch)

        view.addSubview(accessStackView)
        view.addSubview(selectPhotoButton)
        view.addSubview(openSettingsButton)

        NSLayoutConstraint.activate([
            accessStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            accessStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            selectPhotoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            selectPhotoButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            selectPhotoButton.widthAnchor.constraint(equalToConstant: 200),
            selectPhotoButton.heightAnchor.constraint(equalToConstant: 50),

            openSettingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            openSettingsButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            openSettingsButton.widthAnchor.constraint(equalToConstant: 200),
            openSettingsButton.heightAnchor.constraint(equalToConstant: 50)
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

            case .denied, .restricted:
                self.accessStackView.isHidden = true
                self.selectPhotoButton.isHidden = true
                self.openSettingsButton.isHidden = false

            case .notDetermined:
                self.accessStackView.isHidden = false
                self.accessSwitch.isOn = false
                self.selectPhotoButton.isHidden = true
                self.openSettingsButton.isHidden = true

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
}

// MARK: - PHPickerViewControllerDelegate

extension EntryViewController: PHPickerViewControllerDelegate {

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)

        guard let result = results.first else { return }

        result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard let image = object as? UIImage else { return }

            DispatchQueue.main.async {
                // TODO: Handle selected image
                print("Selected image: \(image)")
            }
        }
    }
}
