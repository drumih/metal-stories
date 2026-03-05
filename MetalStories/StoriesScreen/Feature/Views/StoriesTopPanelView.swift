import UIKit

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

    let closeButton = makeCircleButton(systemName: "xmark")
    let resetButton = makeCircleButton(systemName: "arrow.circlepath")
    let saveButton = makeCircleButton(systemName: "arrowshape.down.circle")

    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    var isSaveButtonEnabled: Bool {
        get { saveButton.isUserInteractionEnabled }
        set { saveButton.isUserInteractionEnabled = newValue }
    }

    // MARK: Private

    private enum Layout {
        static let buttonSize: CGFloat = 40
        static let horizontalPadding: CGFloat = 16
        static let buttonSpacing: CGFloat = 12
        static let verticalPadding: CGFloat = 12
    }

    private let titleString: String

    private static func makeCircleButton(systemName: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = Layout.buttonSize / 2
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func setupUI() {
        backgroundColor = .clear
        titleLabel.text = titleString

        addSubview(closeButton)
        addSubview(resetButton)
        addSubview(saveButton)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: Layout.verticalPadding),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -Layout.verticalPadding),

            closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Layout.horizontalPadding),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: Layout.buttonSize),
            closeButton.widthAnchor.constraint(equalTo: closeButton.heightAnchor),

            resetButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -Layout.buttonSpacing),
            resetButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            resetButton.heightAnchor.constraint(equalToConstant: Layout.buttonSize),
            resetButton.widthAnchor.constraint(equalTo: resetButton.heightAnchor),

            saveButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Layout.horizontalPadding),
            saveButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            saveButton.heightAnchor.constraint(equalToConstant: Layout.buttonSize),
            saveButton.widthAnchor.constraint(equalTo: saveButton.heightAnchor),
        ])
    }
}
