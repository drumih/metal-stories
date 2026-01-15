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
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.beginFromCurrentState, .allowUserInteraction]
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
                withDuration: 0.25,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseIn],
                animations: {
                    self.alpha = 0
                },
                completion: { finished in
                    if finished {
                        self.isHidden = true
                    }
                }
            )
        }
        
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)
    }

    // MARK: Private

    private var hideWorkItem: DispatchWorkItem?

    private lazy var indexLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 24, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var blurView: UIVisualEffectView = {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let view = UIVisualEffectView(effect: blurEffect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private func setupUI() {
        alpha = 0
        isHidden = true
        layer.cornerRadius = 20
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        addSubview(blurView)
        blurView.contentView.addSubview(indexLabel)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            indexLabel.topAnchor.constraint(equalTo: blurView.topAnchor, constant: 12),
            indexLabel.leadingAnchor.constraint(equalTo: blurView.leadingAnchor, constant: 24),
            indexLabel.trailingAnchor.constraint(equalTo: blurView.trailingAnchor, constant: -24),
            indexLabel.bottomAnchor.constraint(equalTo: blurView.bottomAnchor, constant: -12),
        ])
    }
}
