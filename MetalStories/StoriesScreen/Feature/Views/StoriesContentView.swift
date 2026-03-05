import UIKit

// MARK: - StoriesContentViewDelegate

protocol StoriesContentViewDelegate: AnyObject {
    func storiesContentViewDidTapClose(_ view: StoriesContentView)
    func storiesContentViewDidTapReset(_ view: StoriesContentView)
    func storiesContentViewDidTapSave(_ view: StoriesContentView)
    func storiesContentViewDidPressShowOriginal(_ view: StoriesContentView)
    func storiesContentViewDidReleaseShowOriginal(_ view: StoriesContentView)
}

// MARK: - StoriesContentView

final class StoriesContentView: UIView {

    // MARK: Lifecycle

    init(
        title: String,
        renderingView: RenderingView,
        canvasAspectRatio: CGFloat,
    ) {
        self.title = title
        self.renderingView = renderingView
        self.canvasAspectRatio = canvasAspectRatio
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    weak var delegate: StoriesContentViewDelegate?

    var isSaveButtonEnabled: Bool {
        get { topPanelView.isSaveButtonEnabled }
        set { topPanelView.isSaveButtonEnabled = newValue }
    }

    var touchTrackingView: TouchTrackingView { touchView }

    func showFilterName(_ name: String) {
        storiesFilterNameView.show(name: name)
    }

    func hideFilterName() {
        storiesFilterNameView.hide()
    }

    // MARK: Private

    private let title: String
    private let renderingView: RenderingView
    private let canvasAspectRatio: CGFloat

    private lazy var touchView: TouchTrackingView = {
        let view = TouchTrackingView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var topPanelView: StoriesTopPanelView = {
        let view = StoriesTopPanelView(title: title)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.zPosition = 1
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
        button.addTarget(
            self,
            action: #selector(showOriginalReleased),
            for: [.touchUpInside, .touchUpOutside, .touchCancel],
        )
        return button
    }()

    private func setupUI() {
        backgroundColor = .black

        let safeArea = safeAreaLayoutGuide

        topPanelView.closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        topPanelView.resetButton.addTarget(self, action: #selector(resetTapped), for: .touchUpInside)
        topPanelView.saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        addSubview(topPanelView)

        renderingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(renderingView)

        addSubview(storiesFilterNameView)
        addSubview(showOriginalButton)

        renderingView.addSubview(touchView)

        let aspectRatio = renderingView.heightAnchor.constraint(
            equalTo: renderingView.widthAnchor,
            multiplier: canvasAspectRatio,
        )
        let preferredWidth = renderingView.widthAnchor.constraint(equalTo: safeArea.widthAnchor)
        preferredWidth.priority = .defaultHigh

        NSLayoutConstraint.activate([
            topPanelView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            topPanelView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            topPanelView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),

            renderingView.topAnchor.constraint(equalTo: topPanelView.bottomAnchor, constant: 12),
            renderingView.centerXAnchor.constraint(equalTo: centerXAnchor),
            renderingView.widthAnchor.constraint(lessThanOrEqualTo: safeArea.widthAnchor),
            preferredWidth,
            renderingView.heightAnchor.constraint(lessThanOrEqualTo: safeArea.heightAnchor),
            renderingView.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor),
            aspectRatio,

            touchView.topAnchor.constraint(equalTo: renderingView.topAnchor),
            touchView.bottomAnchor.constraint(equalTo: renderingView.bottomAnchor),
            touchView.leadingAnchor.constraint(equalTo: renderingView.leadingAnchor),
            touchView.trailingAnchor.constraint(equalTo: renderingView.trailingAnchor),

            storiesFilterNameView.centerXAnchor.constraint(equalTo: centerXAnchor),
            storiesFilterNameView.centerYAnchor.constraint(equalTo: centerYAnchor),
            storiesFilterNameView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            storiesFilterNameView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            showOriginalButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -16),
            showOriginalButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -16),
            showOriginalButton.heightAnchor.constraint(equalToConstant: 40),
            showOriginalButton.widthAnchor.constraint(equalTo: showOriginalButton.heightAnchor),
        ])
    }

    @objc
    private func showOriginalPressed() {
        delegate?.storiesContentViewDidPressShowOriginal(self)
    }

    @objc
    private func showOriginalReleased() {
        delegate?.storiesContentViewDidReleaseShowOriginal(self)
    }

    @objc
    private func closeTapped() {
        delegate?.storiesContentViewDidTapClose(self)
    }

    @objc
    private func resetTapped() {
        delegate?.storiesContentViewDidTapReset(self)
    }

    @objc
    private func saveTapped() {
        delegate?.storiesContentViewDidTapSave(self)
    }
}
