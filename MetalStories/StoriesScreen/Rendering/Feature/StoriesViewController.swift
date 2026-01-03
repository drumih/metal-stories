import UIKit

// TODO: add title
final class StoriesViewController: UIViewController {

    // MARK: Lifecycle

    init(
        gpu: GPU,
        renderingView: RenderingView,
        sceneInput: SceneInput,
        offscreenRenderer: OffscreenRenderer,
        imageData: Data,
    ) {
        self.gpu = gpu
        self.renderingView = renderingView
        self.sceneInput = sceneInput
        self.offscreenRenderer = offscreenRenderer
        self.imageData = imageData

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
            setupFailureUI()
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

    private let sceneInput: SceneInput
    private let offscreenRenderer: OffscreenRenderer
    private var gestureHandler: StoriesGestureHandler?

    private let imageData: Data

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
        let closeButton = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(closeButtonTapped))
        navigationItem.leftBarButtonItem = closeButton
    }

    @objc
    private func closeButtonTapped() {
        dismiss(animated: true)
    }

    // TODO: fix layout errors
    private func setupStoriesUI() {
        view.backgroundColor = .black

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
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor),
            preferredWidth,
            containerView.heightAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.heightAnchor),
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

        let exportButton = UIBarButtonItem(title: "Export", style: .plain, target: self, action: #selector(exportButtonTapped))
        navigationItem.rightBarButtonItem = exportButton
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
                        self?.showSuccessAlert()
                    case .failure:
                        self?.showExportErrorAlert()
                    }
                }
            }
        } catch {
            showExportErrorAlert()
        }
    }

    private func showSuccessAlert() {
        let alert = UIAlertController(
            title: "Success",
            message: "Image saved to photo library",
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func showExportErrorAlert() {
        let alert = UIAlertController(
            title: "Error",
            message: "Failed to export image",
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func setupFailureUI() {
        view.backgroundColor = .systemBackground

        let failureLabel = UILabel()
        failureLabel.text = "Can't load image, try another image"
        failureLabel.textAlignment = .center
        failureLabel.font = .systemFont(ofSize: 17, weight: .medium)
        failureLabel.textColor = .label
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
