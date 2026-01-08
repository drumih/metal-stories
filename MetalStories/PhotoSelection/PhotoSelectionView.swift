import UIKit

// MARK: - PhotoSelectionViewDelegate

protocol PhotoSelectionViewDelegate: AnyObject {
    func photoSelectionViewDidTapSelectPhoto()
    func photoSelectionView(didChangeRenderPassIndex index: Int)
    func photoSelectionViewDidTapUseCachedImage()
    func photoSelectionViewDidTapDeleteCachedImage()
}

// MARK: - PhotoSelectionView

final class PhotoSelectionView: UIView {

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    weak var delegate: PhotoSelectionViewDelegate?

    func configure(selectedRenderPassIndex: Int) {
        renderPassSegmentedControl.selectedSegmentIndex = selectedRenderPassIndex
    }

    func updateCachedImage(_ image: UIImage?) {
        if let image {
            previewImageView.image = image
            previousImageContainerView.isHidden = false
        } else {
            previewImageView.image = nil
            previousImageContainerView.isHidden = true
        }
    }

    // MARK: Private

    private let selectPhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select Photo", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let renderPassSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Simple", "Intermediate", "Tile"])
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let previousImageContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let previewImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 12
        imageView.layer.cornerCurve = .continuous
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let useCachedImageButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Use Cached Image", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemGreen
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 12
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let deleteCachedImageButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let image = UIImage(systemName: "xmark.circle.fill", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.backgroundColor = .systemRed
        button.tintColor = .white
        button.layer.cornerRadius = 15
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private func setupView() {
        backgroundColor = .systemBackground

        selectPhotoButton.addTarget(self, action: #selector(selectPhotoTapped), for: .touchUpInside)
        renderPassSegmentedControl.addTarget(
            self,
            action: #selector(renderPassChanged),
            for: .valueChanged,
        )
        useCachedImageButton.addTarget(self, action: #selector(useCachedImageTapped), for: .touchUpInside)
        deleteCachedImageButton.addTarget(self, action: #selector(deleteCachedImageTapped), for: .touchUpInside)

        previewImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        previewImageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        selectPhotoButton.setContentCompressionResistancePriority(.required, for: .vertical)
        renderPassSegmentedControl.setContentCompressionResistancePriority(.required, for: .vertical)
        useCachedImageButton.setContentCompressionResistancePriority(.required, for: .vertical)

        previousImageContainerView.addSubview(previewImageView)
        previousImageContainerView.addSubview(deleteCachedImageButton)
        previousImageContainerView.addSubview(useCachedImageButton)

        addSubview(selectPhotoButton)
        addSubview(previousImageContainerView)
        addSubview(renderPassSegmentedControl)

        NSLayoutConstraint.activate([
            renderPassSegmentedControl.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            renderPassSegmentedControl.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            renderPassSegmentedControl.bottomAnchor.constraint(
                equalTo: safeAreaLayoutGuide.bottomAnchor,
                constant: -16,
            ),

            selectPhotoButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            selectPhotoButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            selectPhotoButton.bottomAnchor.constraint(equalTo: renderPassSegmentedControl.topAnchor, constant: -16),
            selectPhotoButton.heightAnchor.constraint(equalToConstant: 50),

            previousImageContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            previousImageContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            previousImageContainerView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
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
        delegate?.photoSelectionViewDidTapSelectPhoto()
    }

    @objc
    private func renderPassChanged(_ sender: UISegmentedControl) {
        delegate?.photoSelectionView(didChangeRenderPassIndex: sender.selectedSegmentIndex)
    }

    @objc
    private func useCachedImageTapped() {
        delegate?.photoSelectionViewDidTapUseCachedImage()
    }

    @objc
    private func deleteCachedImageTapped() {
        delegate?.photoSelectionViewDidTapDeleteCachedImage()
    }
}
