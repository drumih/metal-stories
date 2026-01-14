import UIKit

// MARK: - StoriesTopPanelViewDelegate

protocol StoriesTopPanelViewDelegate: AnyObject {
    func storiesTopPanelDidTapClose()
    func storiesTopPanelDidTapReset()
    func storiesTopPanelDidTapSave()
    func storiesTopPanelDidChangeShowOriginal(isActive: Bool)
}

// MARK: - StoriesTopPanelView

final class StoriesTopPanelView: UIView {

    // MARK: Lifecycle

    init(title: String) {
        titleString = title
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    weak var delegate: StoriesTopPanelViewDelegate?

    var isSaveButtonEnabled: Bool {
        get { saveButton.isUserInteractionEnabled }
        set { saveButton.isUserInteractionEnabled = newValue }
    }

    // MARK: Private

    private let titleString: String

    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var resetButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.circlepath"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var showOriginalButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "eye"), for: .normal)
        button.setImage(UIImage(systemName: "eye.fill"), for: .highlighted)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(showOriginalPressed), for: .touchDown)
        button.addTarget(self, action: #selector(showOriginalReleased), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }()

    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrowshape.down.circle"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = titleString
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private func setupUI() {
        backgroundColor = .clear

        addSubview(closeButton)
        addSubview(resetButton)
        addSubview(showOriginalButton)
        addSubview(saveButton)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),

            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 40),
            closeButton.widthAnchor.constraint(equalTo: closeButton.heightAnchor),

            resetButton.trailingAnchor.constraint(equalTo: showOriginalButton.leadingAnchor, constant: -12),
            resetButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            resetButton.heightAnchor.constraint(equalToConstant: 40),
            resetButton.widthAnchor.constraint(equalTo: resetButton.heightAnchor),

            showOriginalButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -12),
            showOriginalButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            showOriginalButton.heightAnchor.constraint(equalToConstant: 40),
            showOriginalButton.widthAnchor.constraint(equalTo: showOriginalButton.heightAnchor),

            saveButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            saveButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: 40),
            saveButton.widthAnchor.constraint(equalTo: saveButton.heightAnchor),
        ])
    }

    @objc
    private func closeButtonTapped() {
        delegate?.storiesTopPanelDidTapClose()
    }

    @objc
    private func resetButtonTapped() {
        delegate?.storiesTopPanelDidTapReset()
    }

    @objc
    private func saveButtonTapped() {
        delegate?.storiesTopPanelDidTapSave()
    }

    @objc
    private func showOriginalPressed() {
        delegate?.storiesTopPanelDidChangeShowOriginal(isActive: true)
    }

    @objc
    private func showOriginalReleased() {
        delegate?.storiesTopPanelDidChangeShowOriginal(isActive: false)
    }
}
