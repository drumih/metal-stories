import UIKit

protocol FailureViewDelegate: AnyObject {
    func failureViewDidTapBack()
}

final class FailureView: UIView {

    // MARK: Lifecycle

    init(error: Error) {
        self.error = error
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    weak var delegate: FailureViewDelegate?

    // MARK: Private

    private let error: Error

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(failureLabel)
        stackView.addArrangedSubview(backButton)
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
        button.setTitle("Go Back", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.tintColor = .white
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        return button
    }()

    private func setupUI() {
        backgroundColor = .black
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
        delegate?.failureViewDidTapBack()
    }
}
