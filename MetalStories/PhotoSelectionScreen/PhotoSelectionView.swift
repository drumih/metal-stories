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

    func updateCachedImagePreview(_ image: UIImage?) {
        if let image {
            cachedImageView.image = image
            cachedImageContainerView.isHidden = false
        } else {
            cachedImageView.image = nil
            cachedImageContainerView.isHidden = true
        }
    }

    // MARK: Private

    private let selectPhotoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Select Photo", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 14
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let renderPassSegmentedControl: UISegmentedControl = {
        let control = UISegmentedControl(items: ["Simple", "Intermediate", "Tile", "Direct"])
        control.translatesAutoresizingMaskIntoConstraints = false
        return control
    }()

    private let cachedImageContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    private let cachedImageView: UIImageView = {
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
        button.layer.cornerRadius = 14
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let deleteCachedImageButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        let image = UIImage(systemName: "xmark", withConfiguration: config)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 16
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

        cachedImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        cachedImageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        selectPhotoButton.setContentCompressionResistancePriority(.required, for: .vertical)
        renderPassSegmentedControl.setContentCompressionResistancePriority(.required, for: .vertical)
        useCachedImageButton.setContentCompressionResistancePriority(.required, for: .vertical)

        cachedImageContainerView.addSubview(cachedImageView)
        cachedImageContainerView.addSubview(useCachedImageButton)
        cachedImageContainerView.addSubview(deleteCachedImageButton)

        addSubview(selectPhotoButton)
        addSubview(cachedImageContainerView)
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

            cachedImageContainerView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            cachedImageContainerView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            cachedImageContainerView.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 16),
            cachedImageContainerView.bottomAnchor.constraint(equalTo: selectPhotoButton.topAnchor, constant: -16),

            cachedImageView.topAnchor.constraint(equalTo: cachedImageContainerView.topAnchor),
            cachedImageView.leadingAnchor.constraint(equalTo: cachedImageContainerView.leadingAnchor),
            cachedImageView.trailingAnchor.constraint(equalTo: cachedImageContainerView.trailingAnchor),
            cachedImageView.bottomAnchor.constraint(equalTo: useCachedImageButton.topAnchor, constant: -12),

            useCachedImageButton.leadingAnchor.constraint(equalTo: cachedImageContainerView.leadingAnchor),
            useCachedImageButton.trailingAnchor.constraint(equalTo: deleteCachedImageButton.leadingAnchor, constant: -12),
            useCachedImageButton.bottomAnchor.constraint(equalTo: cachedImageContainerView.bottomAnchor),
            useCachedImageButton.heightAnchor.constraint(equalToConstant: 50),

            deleteCachedImageButton.trailingAnchor.constraint(equalTo: cachedImageContainerView.trailingAnchor),
            deleteCachedImageButton.bottomAnchor.constraint(equalTo: cachedImageContainerView.bottomAnchor),
            deleteCachedImageButton.widthAnchor.constraint(equalToConstant: 50),
            deleteCachedImageButton.heightAnchor.constraint(equalToConstant: 50),
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
