import UIKit

final class OffsetAnimator {

    // MARK: Lifecycle
    
    private let sceneInput: SceneInput

    init(sceneInput: SceneInput) {
        self.sceneInput = sceneInput
    }

    deinit {
        cancel()
    }

    // MARK: Internal

    var isAnimating: Bool {
        animation != nil
    }

    func animate(from startOffset: Float, to targetOffset: Float) {
        let distance = abs(targetOffset - startOffset)

        // TODO: use eps constant
        if distance < 0.0001 {
            sceneInput.filterOffset = targetOffset
            cancel()
            return
        }

        // Duration scales with distance for a consistent snap feel.
        let clampedDuration = max(0.28, min(0.7, Double(distance) * 0.45))

        animation = Animation(
            startValue: startOffset,
            targetValue: targetOffset,
            startTime: CACurrentMediaTime(),
            duration: clampedDuration
        )

        displayLink?.invalidate()
        let displayLink = CADisplayLink(target: self, selector: #selector(handleAnimation))
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
        animation = nil
    }

    // MARK: Private

    private struct Animation {
        let startValue: Float
        let targetValue: Float
        let startTime: CFTimeInterval
        let duration: CFTimeInterval
    }

    private var animation: Animation?
    private var displayLink: CADisplayLink?

    @objc
    private func handleAnimation() {
        guard let animation else {
            cancel()
            return
        }
        let now = CACurrentMediaTime()
        let elapsed = now - animation.startTime
        let progress = min(1.0, elapsed / animation.duration)

        // Ease-out cubic for a smooth finish.
        let eased = 1.0 - pow(1.0 - progress, 3.0)
        let newOffset = animation.startValue + Float(eased) * (animation.targetValue - animation.startValue)
        
        sceneInput.filterOffset = newOffset

        if progress >= 1.0 {
            sceneInput.filterOffset = animation.targetValue
            cancel()
            return
        }
    }
}
