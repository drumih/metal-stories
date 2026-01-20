import UIKit

// MARK: - StoriesFilterNameView

final class StoriesFilterNameView: UIView {

    // MARK: Lifecycle

    init() {
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Internal

    func show(name: String) {
        layer.removeAllAnimations()
        hideWorkItem?.cancel()
        hideWorkItem = nil

        indexLabel.text = name
        isHidden = false
        transform = .identity

        UIView.animate(
            withDuration: Animation.showDuration,
            delay: 0,
            usingSpringWithDamping: Animation.springDamping,
            initialSpringVelocity: Animation.springVelocity,
            options: [.beginFromCurrentState, .allowUserInteraction],
        ) {
            self.alpha = 1.0
        }
    }

    func hide() {
        layer.removeAllAnimations()
        hideWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }

            UIView.animate(
                withDuration: Animation.hideDuration,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseIn],
                animations: {
                    self.alpha = 0
                },
                completion: { finished in
                    if finished {
                        self.isHidden = true
                    }
                },
            )
        }

        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Animation.hideDelay, execute: workItem)
    }

    // MARK: Private

    private enum Animation {
        static let showDuration: TimeInterval = 0.2
        static let hideDuration: TimeInterval = 0.25
        static let hideDelay: TimeInterval = 0.15
        static let springDamping: CGFloat = 0.8
        static let springVelocity: CGFloat = 0.5
    }

    private var hideWorkItem: DispatchWorkItem?

    private lazy var indexLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private func setupUI() {
        alpha = 0
        isHidden = true
        backgroundColor = .clear
        layer.cornerRadius = 20
        layer.masksToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        indexLabel.layer.shadowColor = UIColor.black.cgColor
        indexLabel.layer.shadowOpacity = 0.25
        indexLabel.layer.shadowRadius = 4
        indexLabel.layer.shadowOffset = CGSize(width: 0, height: 2)
        indexLabel.layer.masksToBounds = false
        addSubview(indexLabel)

        NSLayoutConstraint.activate([
            indexLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            indexLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            indexLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            indexLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
        ])
    }
}
