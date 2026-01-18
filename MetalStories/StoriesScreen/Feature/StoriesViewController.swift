import UIKit

// MARK: - StoriesViewController

final class StoriesViewController: UIViewController {

    // MARK: Lifecycle

    init(
        gpu: GPU,
        renderingView: RenderingView,
        sceneInput: SceneInput,
        offscreenRenderer: OffscreenRenderer,
        inputImageData: Data,
        titleString: String,
        availableFiltersCount: Int16,
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
        view.backgroundColor = .systemBackground
        view.overrideUserInterfaceStyle = .dark
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

    private static let targetImageDimension = 2016
    private static let minImageDimension = 128
    private static let maxExportImageWidth: CGFloat = 1080

    private static let filterNames: [String] = [
        "Original",
        "Very Simple",
        "Sepia",
        "Noir Chrome",
        "Fire and Ice",
        "Teal Orange Cinema",
        "Cross Process",
        "Bleach Bypass",
        "Orange Sunset",
    ]

    private let gpu: GPU
    private let renderingView: RenderingView

    private lazy var contentView: StoriesContentView = {
        let view = StoriesContentView(
            title: titleString,
            renderingView: renderingView,
            canvasAspectRatio: CGFloat(sceneInput.canvasAspectRatio),
        )
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        return view
    }()

    private let sceneInput: SceneInput
    private let offscreenRenderer: OffscreenRenderer
    private var gestureHandler: StoriesGestureHandler?

    private let inputImageData: Data
    private let titleString: String
    private let availableFiltersCount: Int16

    private var isSavingEnabled = true {
        didSet {
            contentView.isSaveButtonEnabled = isSavingEnabled
        }
    }

}

// MARK: - Image Handling

extension StoriesViewController {
    private func prepareImage() throws {
        let (cgImage, orientation) = try DataToCGImagePreprocessing.loadCGImage(
            from: inputImageData
        )
        let preparationResult = try CGImageToMetalTexturePreprocessing.prepareCGImage(
            cgImage: cgImage,
            orientation: orientation,
            targetDimension: Self.targetImageDimension,
            minPossibleDimension: Self.minImageDimension,
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
                colorSpace: CGColorSpace(name: CGColorSpace.displayP3)!,
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
            touchTrackingView: contentView.touchTrackingView,
            sceneInput: sceneInput,
        )
        gestureHandler?.offsetAnimatorDelegate = self
    }

    private func setupUI() {
        view.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: view.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
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
        contentView.showFilterName(filterName)
    }

    func offsetAnimatorDidEndAnimation(targetOffset _: Float) {
        contentView.hideFilterName()
    }
}

// MARK: StoriesContentViewDelegate

extension StoriesViewController: StoriesContentViewDelegate {
    func storiesContentViewDidTapClose(_: StoriesContentView) {
        dismiss(animated: true)
    }

    func storiesContentViewDidTapReset(_: StoriesContentView) {
        gestureHandler?.resetTracking()
        sceneInput.reset()
    }

    func storiesContentViewDidTapSave(_: StoriesContentView) {
        saveImage()
    }

    func storiesContentViewDidPressShowOriginal(_: StoriesContentView) {
        sceneInput.showOriginal = true
    }

    func storiesContentViewDidReleaseShowOriginal(_: StoriesContentView) {
        sceneInput.showOriginal = false
    }
}
