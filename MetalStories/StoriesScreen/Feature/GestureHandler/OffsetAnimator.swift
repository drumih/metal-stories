import UIKit

// MARK: - OffsetAnimatorDelegate

protocol OffsetAnimatorDelegate: AnyObject {
    func offsetAnimatorDidStartAnimation(targetOffset: Float)
    func offsetAnimatorDidEndAnimation(targetOffset: Float)
}

// MARK: - OffsetAnimator

/// Animates the filter offset to snap to integer values using ease-out cubic easing.
/// Uses CADisplayLink for frame-synchronized updates.
final class OffsetAnimator {

    // MARK: Lifecycle

    init(sceneInput: SceneInput) {
        self.sceneInput = sceneInput
    }

    deinit {
        cancel()
    }

    // MARK: Internal

    weak var delegate: OffsetAnimatorDelegate?

    var isAnimating: Bool {
        animation != nil
    }

    func animate(from startOffset: Float, to targetOffset: Float) {
        let distance = abs(targetOffset - startOffset)

        guard distance > AnimationTiming.minimumDistance else {
            sceneInput.filterOffset = targetOffset
            cancel()
            return
        }

        let clampedDuration = clamp(
            value: Double(distance) * AnimationTiming.durationPerUnit,
            min: AnimationTiming.minimumDuration,
            max: AnimationTiming.maximumDuration,
        )

        animation = Animation(
            startValue: startOffset,
            targetValue: targetOffset,
            startTime: CACurrentMediaTime(),
            duration: clampedDuration,
        )

        startDisplayLink()
        delegate?.offsetAnimatorDidStartAnimation(targetOffset: targetOffset)
    }

    /// Stops the animation and notifies the delegate.
    func cancel() {
        let wasAnimating = animation != nil
        let targetValue = animation?.targetValue

        stopDisplayLink()

        if wasAnimating, let targetValue {
            delegate?.offsetAnimatorDidEndAnimation(targetOffset: targetValue)
        }
    }

    // MARK: Private

    private enum AnimationTiming {
        /// Distance threshold below which we skip animation and snap immediately
        static let minimumDistance: Float = 0.001

        /// Duration multiplier per unit of distance
        static let durationPerUnit: Double = 0.45

        /// Minimum animation duration for snappy feel
        static let minimumDuration: Double = 0.28

        /// Maximum duration to prevent sluggish animations
        static let maximumDuration: Double = 0.70
    }

    private struct Animation {
        let startValue: Float
        let targetValue: Float
        let startTime: CFTimeInterval
        let duration: CFTimeInterval
    }

    private let sceneInput: SceneInput

    private var animation: Animation?
    private var displayLink: CADisplayLink?

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        animation = nil
    }

    private func startDisplayLink() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: self, selector: #selector(handleAnimation))
        displayLink = link
        link.add(to: .main, forMode: .common)
    }

    @objc
    private func handleAnimation() {
        guard let animation else {
            cancel()
            return
        }
        let now = CACurrentMediaTime()
        let elapsed = now - animation.startTime
        let progress = min(1.0, elapsed / animation.duration)

        // Ease-out cubic for a smooth animation finish
        let eased = 1.0 - pow(1.0 - progress, 3.0)
        let newOffset = animation.startValue + Float(eased) * (animation.targetValue - animation.startValue)

        sceneInput.filterOffset = newOffset

        if progress >= 1.0 {
            let targetValue = animation.targetValue
            sceneInput.filterOffset = targetValue

            stopDisplayLink()

            delegate?.offsetAnimatorDidEndAnimation(targetOffset: targetValue)
            return
        }
    }
}
