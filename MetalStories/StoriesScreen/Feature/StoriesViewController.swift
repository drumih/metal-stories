import UIKit

// MARK: - StoriesViewController

// TODO: fix opposite filtering
// TODO: add filters name

final class StoriesViewController: UIViewController {

    // MARK: Lifecycle

    init(
        gpu: GPU,
        renderingView: RenderingView,
        sceneInput: SceneInput,
        offscreenRenderer: OffscreenRenderer,
        inputImageData: Data,
        titleString: String,
        availableFiltersCount: Int16
    ) {
        self.gpu = gpu
        self.renderingView = renderingView
        self.sceneInput = sceneInput
        self.offscreenRenderer = offscreenRenderer
        self.inputImageData = inputImageData
        self.titleString = titleString
        self.availableFiltersCount = availableFiltersCount

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try prepareImage()
            setupUI()
            setupGestureHandler()
        } catch {
            setupFailureUI(error: error)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneInput.showOriginal = false
    }

    // MARK: Private

    private static let maxImageDimension: CGFloat = 2016
    private static let maxExportImageWidth: CGFloat = 1080
    private static let filterNames: [String] = [
        "Original",
        "Very Simple",
        "Sepia",
        "Noir Chrome",
        "Fire and Ice",
        "Teal Orange Cinema",
        "Cross Process",
    ]

    private let gpu: GPU
    private let renderingView: RenderingView

    private lazy var touchTrackingView: TouchTrackingView = {
        let view = TouchTrackingView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        return view
    }()

    private lazy var topPanelView: StoriesTopPanelView = {
        let view = StoriesTopPanelView(title: titleString)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.zPosition = 1
        view.delegate = self
        return view
    }()

    private lazy var storiesFilterNameView: StoriesFilterNameView = {
        let view = StoriesFilterNameView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var showOriginalButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "circle.lefthalf.filled"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showOriginalPressed), for: .touchDown)
        button.addTarget(self, action: #selector(showOriginalReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }()

    private let sceneInput: SceneInput
    private let offscreenRenderer: OffscreenRenderer
    private var gestureHandler: StoriesGestureHandler?

    private let inputImageData: Data
    private let titleString: String
    private let availableFiltersCount: Int16

    private var isSavingEnabled = true {
        didSet {
            topPanelView.isSaveButtonEnabled = isSavingEnabled
        }
    }

}

// MARK: - Image Handling

extension StoriesViewController {
    private func prepareImage() throws {
        let cgImage = try DataToCGImagePreprocessing.loadCGImage(
            from: inputImageData,
            maxPixelSize: Self.maxImageDimension,
        )
        let preparationResult = try CGImageToMetalTexturePreprocessing.prepareCGImage(
            cgImage: cgImage.0,
            gpu: gpu,
        )
        sceneInput.setPreparationResult(preparationResult)
    }

    private func saveImage() {
        guard isSavingEnabled else { return }
        isSavingEnabled = false

        let cgImage: CGImage
        do {
            let width = Self.maxExportImageWidth
            let height = round(width * CGFloat(sceneInput.canvasAspectRatio))
            cgImage = try offscreenRenderer.renderImageToOffscreenTexture(
                size: .init(width: width, height: height),
                colorSpace: CGColorSpaceCreateDeviceRGB(),
            )
        } catch {
            isSavingEnabled = true
            showAlert(title: "Error", message: error.localizedDescription)
            return
        }

        ImageSaver.saveImage(
            cgImage,
            newOrientation: .up,
            originalData: inputImageData,
            callbackQueue: .main,
        ) { [weak self] result in
            self?.isSavingEnabled = true
            switch result {
            case .success:
                self?.showAlert(title: "Success", message: "Image saved to photo library")
            case .failure(let error):
                self?.showAlert(title: "Error", message: error.localizedDescription)
            }
        }
    }
}

// MARK: - UI

extension StoriesViewController {

    private func setupGestureHandler() {
        gestureHandler = StoriesGestureHandler(
            touchTrackingView: touchTrackingView,
            sceneInput: sceneInput,
        )
        gestureHandler?.offsetAnimatorDelegate = self
    }

    private func setupUI() {
        view.backgroundColor = .black

        let safeArea = view.safeAreaLayoutGuide

        view.addSubview(topPanelView)

        renderingView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(renderingView)

        view.addSubview(storiesFilterNameView)
        view.addSubview(showOriginalButton)

        touchTrackingView.translatesAutoresizingMaskIntoConstraints = false
        renderingView.addSubview(touchTrackingView)

        let aspectRatio = renderingView.heightAnchor.constraint(
            equalTo: renderingView.widthAnchor,
            multiplier: .init(sceneInput.canvasAspectRatio)
        )
        let preferredWidth = renderingView.widthAnchor.constraint(equalTo: safeArea.widthAnchor)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            topPanelView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            topPanelView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            topPanelView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),

            renderingView.topAnchor.constraint(equalTo: topPanelView.bottomAnchor, constant: 12),
            renderingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            renderingView.widthAnchor.constraint(lessThanOrEqualTo: safeArea.widthAnchor),
            preferredWidth,
            renderingView.heightAnchor.constraint(lessThanOrEqualTo: safeArea.heightAnchor),
            renderingView.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor),
            aspectRatio,

            touchTrackingView.topAnchor.constraint(equalTo: renderingView.topAnchor),
            touchTrackingView.bottomAnchor.constraint(equalTo: renderingView.bottomAnchor),
            touchTrackingView.leadingAnchor.constraint(equalTo: renderingView.leadingAnchor),
            touchTrackingView.trailingAnchor.constraint(equalTo: renderingView.trailingAnchor),

            storiesFilterNameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            storiesFilterNameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            storiesFilterNameView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            storiesFilterNameView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),

            showOriginalButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            showOriginalButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16),
            showOriginalButton.heightAnchor.constraint(equalToConstant: 40),
            showOriginalButton.widthAnchor.constraint(equalTo: showOriginalButton.heightAnchor),
        ])
    }

    private func setupFailureUI(error: Error) {
        let failureView = StoriesFailureView(error: error)
        failureView.translatesAutoresizingMaskIntoConstraints = false
        failureView.delegate = self

        view.addSubview(failureView)

        NSLayoutConstraint.activate([
            failureView.topAnchor.constraint(equalTo: view.topAnchor),
            failureView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            failureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            failureView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func showAlert(
        title: String,
        message: String,
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc
    private func showOriginalPressed() {
        sceneInput.showOriginal = true
    }

    @objc
    private func showOriginalReleased() {
        sceneInput.showOriginal = false
    }
}

// MARK: StoriesTopPanelViewDelegate

extension StoriesViewController: StoriesTopPanelViewDelegate {
    func storiesTopPanelDidTapClose() {
        dismiss(animated: true)
    }

    func storiesTopPanelDidTapReset() {
        gestureHandler?.resetTracking()
        sceneInput.reset()
    }

    func storiesTopPanelDidTapSave() {
        saveImage()
    }

}

// MARK: StoriesFailureViewDelegate

extension StoriesViewController: StoriesFailureViewDelegate {
    func storiesFailureViewDidTapBack() {
        dismiss(animated: true)
    }
}

// MARK: OffsetAnimatorDelegate

extension StoriesViewController: OffsetAnimatorDelegate {
    func offsetAnimatorDidStartAnimation(targetOffset: Float) {
        let index = Int(round(targetOffset))
        let filtersCount = Int(availableFiltersCount)
        let normalizedIndex = filtersCount > 0
            ? (index % filtersCount + filtersCount) % filtersCount
            : index
        let filterName = normalizedIndex >= 0 && normalizedIndex < Self.filterNames.count
            ? Self.filterNames[normalizedIndex]
            : "Filter \(normalizedIndex)"
        storiesFilterNameView.show(name: filterName)
    }

    func offsetAnimatorDidEndAnimation(targetOffset: Float) {
        storiesFilterNameView.hide()
    }
}
