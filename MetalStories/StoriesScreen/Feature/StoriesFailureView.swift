import UIKit

protocol StoriesFailureViewDelegate: AnyObject {
    func storiesFailureViewDidTapBack()
}

final class StoriesFailureView: UIView {

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

    weak var delegate: StoriesFailureViewDelegate?

    // MARK: Private

    private let error: Error

    private func setupUI() {
        backgroundColor = .black

        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let failureLabel = UILabel()
        failureLabel.text = "Can't load image\n\n\(error.localizedDescription)"
        failureLabel.textAlignment = .center
        failureLabel.font = .systemFont(ofSize: 17, weight: .medium)
        failureLabel.textColor = .white
        failureLabel.numberOfLines = 0

        let backButton = UIButton(type: .system)
        backButton.setTitle("Go Back", for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        backButton.tintColor = .white
        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        backButton.layer.cornerRadius = 12
        backButton.contentEdgeInsets = UIEdgeInsets(top: 12, left: 24, bottom: 12, right: 24)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

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
