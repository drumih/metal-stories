import UIKit

// MARK: - StoriesFailureViewDelegate

protocol StoriesFailureViewDelegate: AnyObject {
    func storiesFailureViewDidTapBack()
}

// MARK: - StoriesFailureView

final class StoriesFailureView: UIView {

    // MARK: Lifecycle

    init(error: Error) {
        self.error = error
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    weak var delegate: StoriesFailureViewDelegate?

    // MARK: Private

    private let error: Error

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private lazy var failureLabel: UILabel = {
        let label = UILabel()
        label.text = "Can't load image\n\n\(error.localizedDescription)"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 0
        return label
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        var title = AttributedString("Go Back")
        title.font = .systemFont(ofSize: 17, weight: .semibold)
        configuration.attributedTitle = title
        configuration.baseForegroundColor = .white
        configuration.background.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        configuration.background.cornerRadius = 12
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
        button.configuration = configuration
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()

    private func setupUI() {
        backgroundColor = .black

        stackView.addArrangedSubview(failureLabel)
        stackView.addArrangedSubview(backButton)

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
        ])
    }

    @objc
    private func backButtonTapped() {
        delegate?.storiesFailureViewDidTapBack()
    }
}
