import UIKit

final class StoriesViewController: UIViewController {

    // MARK: Lifecycle

    init(
        gpu: GPU,
        renderingView: RenderingView,
        sceneInput: SceneInput,
        offscreenRenderer: OffscreenRenderer,
        imageData: Data,
        title: String,
    ) {
        self.gpu = gpu
        self.renderingView = renderingView
        self.sceneInput = sceneInput
        self.offscreenRenderer = offscreenRenderer
        self.imageData = imageData
        self.titleString = title

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCommonUI()
        do {
            try prepareImage()
            setupStoriesUI()
            setupGestureHandler()
        } catch {
            setupFailureUI(error: error)
        }
    }

    // MARK: Private

    private static let maxImageSize: CGFloat = 1920
    private static let imageOutputSize = CGSize(width: 1080, height: 1920)

    private let gpu: GPU
    private let renderingView: RenderingView
    private let touchTrackingView: TouchTrackingView = {
        let view = TouchTrackingView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }()
    private let topContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private let sceneInput: SceneInput
    private let offscreenRenderer: OffscreenRenderer
    private var gestureHandler: StoriesGestureHandler?

    private let imageData: Data

    private let titleString: String

    private func prepareImage() throws {
        let cgImage = try DataToCGImagePreprocessing.loadCGImage(
            from: imageData,
            maxPixelSize: Self.maxImageSize,
        )
        let preparationResult = try CGImageToMetalTexturePreprocessing.prepareCGImage(
            cgImage: cgImage.0,
            gpu: gpu,
        )
        sceneInput.setPreparationResult(preparationResult)
    }

    private func setupCommonUI() {
        view.backgroundColor = .black
        
        let safeArea = view.safeAreaLayoutGuide

        topContainer.translatesAutoresizingMaskIntoConstraints = false
        topContainer.layer.zPosition = 1
        view.addSubview(topContainer)

        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.layer.cornerRadius = 20
        closeButton.clipsToBounds = true
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        topContainer.addSubview(closeButton)

        let resetButton = UIButton(type: .system)
        resetButton.setImage(UIImage(systemName: "arrow.circlepath"), for: .normal)
        resetButton.tintColor = .white
        resetButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.layer.cornerRadius = 20
        resetButton.clipsToBounds = true
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        topContainer.addSubview(resetButton)

        let saveButton = UIButton(type: .system)
        saveButton.setImage(UIImage(systemName: "arrowshape.down.circle"), for: .normal)
        saveButton.tintColor = .white
        saveButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.layer.cornerRadius = 20
        saveButton.clipsToBounds = true
        saveButton.addTarget(self, action: #selector(exportButtonTapped), for: .touchUpInside)
        topContainer.addSubview(saveButton)

        let titleLabel = UILabel()
        titleLabel.text = titleString
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        topContainer.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            topContainer.topAnchor.constraint(equalTo: safeArea.topAnchor),
            topContainer.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            topContainer.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),

            titleLabel.topAnchor.constraint(equalTo: topContainer.topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: topContainer.centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: topContainer.bottomAnchor, constant: -12),

            closeButton.leadingAnchor.constraint(equalTo: topContainer.leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            closeButton.widthAnchor.constraint(equalTo: closeButton.heightAnchor),

            resetButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),
            resetButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            resetButton.heightAnchor.constraint(equalToConstant: 40),
            resetButton.widthAnchor.constraint(equalTo: resetButton.heightAnchor),

            saveButton.trailingAnchor.constraint(equalTo: topContainer.trailingAnchor, constant: -16),
            saveButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 40),
            saveButton.widthAnchor.constraint(equalTo: saveButton.heightAnchor),
        ])
    }

    @objc
    private func closeButtonTapped() {
        dismiss(animated: true)
    }

    @objc
    private func resetButtonTapped() {
        gestureHandler?.resetTracking()
        sceneInput.reset()
    }

    // TODO: fix layout errors
    private func setupStoriesUI() {

        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)

        renderingView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(renderingView)

        touchTrackingView.translatesAutoresizingMaskIntoConstraints = false
        renderingView.addSubview(touchTrackingView)

        let aspectRatio = containerView.heightAnchor.constraint(equalTo: containerView.widthAnchor, multiplier: 16.0 / 9.0)
        let preferredWidth = containerView.widthAnchor.constraint(equalTo: view.safeAreaLayoutGuide.widthAnchor)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: topContainer.bottomAnchor, constant: 12),
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor),
            preferredWidth,
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor),
            containerView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor),
            aspectRatio,

            renderingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            renderingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            renderingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            renderingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),

            touchTrackingView.topAnchor.constraint(equalTo: renderingView.topAnchor),
            touchTrackingView.bottomAnchor.constraint(equalTo: renderingView.bottomAnchor),
            touchTrackingView.leadingAnchor.constraint(equalTo: renderingView.leadingAnchor),
            touchTrackingView.trailingAnchor.constraint(equalTo: renderingView.trailingAnchor),
        ])
    }

    @objc
    private func exportButtonTapped() {
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        do {
            let cgImage = try offscreenRenderer.renderImageToOffscreenTexture(
                size: Self.imageOutputSize,
                colorSpace: colorSpace,
            )

            ImageSaver.saveImage(
                cgImage,
                newOrientation: .up,
                originalData: imageData,
            ) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.showAlert(title: "Success", message: "Image saved to photo library")
                    case .failure:
                        self?.showAlert(title: "Error", message: "Failed to save image")
                    }
                }
            }
        } catch {
            showAlert(title: "Error", message: "Failed to export image")
        }
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupFailureUI(error: Error) {
        view.backgroundColor = .black

        let failureLabel = UILabel()
        failureLabel.text = "Can't load image, try another image:\n`\(error.localizedDescription)`"
        failureLabel.textAlignment = .center
        failureLabel.font = .systemFont(ofSize: 17, weight: .medium)
        failureLabel.textColor = .white
        failureLabel.numberOfLines = 0
        failureLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(failureLabel)

        NSLayoutConstraint.activate([
            failureLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            failureLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            failureLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            failureLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])
    }

    private func setupGestureHandler() {
        gestureHandler = StoriesGestureHandler(
            touchTrackingView: touchTrackingView,
            sceneInput: sceneInput,
        )
    }
}
