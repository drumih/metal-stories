import UIKit

final class SingleFingerGestureHandler {

    // MARK: Lifecycle

    init(sceneInput: SceneInput) {
        self.sceneInput = sceneInput
    }

    deinit {
        cancelFilterOffsetAnimation()
    }

    // MARK: Internal

    var isGestureActive: Bool {
        snapshot != nil
    }

    func startGesture(
        with touch: UITouch,
        in overlay: UIView,
    ) {
        cancelFilterOffsetAnimation()
        let startPoint = touch.location(in: overlay)
        snapshot = Snapshot(
            startPoint: startPoint,
            initialFilterOffset: sceneInput.filterOffset,
            lastPoint: startPoint,
            lastTimestamp: touch.timestamp,
            lastVelocity: 0,
        )
    }

    func updateGesture(
        with touch: UITouch,
        in overlay: UIView,
    ) {
        if snapshot == nil {
            startGesture(with: touch, in: overlay)
        }
        guard var snapshot else { return }
        cancelFilterOffsetAnimation()

        let bounds = overlay.bounds
        guard bounds.width > 0 else { return }

        let currentPoint = touch.location(in: overlay)
        let deltaX = Float((currentPoint.x - snapshot.startPoint.x) / bounds.width)
        sceneInput.filterOffset = snapshot.initialFilterOffset + deltaX

        let currentTime = touch.timestamp
        let dt = currentTime - snapshot.lastTimestamp
        if dt > 0 {
            let velocity = Float((currentPoint.x - snapshot.lastPoint.x) / bounds.width) / Float(dt)
            snapshot.lastVelocity = velocity
        }
        snapshot.lastPoint = currentPoint
        snapshot.lastTimestamp = currentTime
        self.snapshot = snapshot
    }

    func snapOffsetIfNeeded() {
        guard let snapshot else { return }
        let currentOffset = sceneInput.filterOffset
        let velocity = snapshot.lastVelocity
        let targetOffset = calculateSnapTarget(
            currentPosition: currentOffset,
            velocity: velocity,
        )

        startFilterOffsetAnimation(to: targetOffset)
    }

    func resetTracking() {
        snapshot = nil
    }

    func cancelAnimations() {
        cancelFilterOffsetAnimation()
    }

    // MARK: Private

    private struct Snapshot {
        let startPoint: CGPoint
        let initialFilterOffset: Float
        var lastPoint: CGPoint
        var lastTimestamp: TimeInterval
        var lastVelocity: Float
    }

    private struct FilterOffsetAnimation {
        let startValue: Float
        let targetValue: Float
        let startTime: CFTimeInterval
        let duration: CFTimeInterval
    }

    private let sceneInput: SceneInput
    private var snapshot: Snapshot?
    private var filterOffsetAnimation: FilterOffsetAnimation?
    private var filterOffsetDisplayLink: CADisplayLink?

    private func cancelFilterOffsetAnimation() {
        filterOffsetDisplayLink?.invalidate()
        filterOffsetDisplayLink = nil
        filterOffsetAnimation = nil
    }

    private func startFilterOffsetAnimation(
        to targetOffset: Float
    ) {
        let startOffset = sceneInput.filterOffset
        let distance = abs(targetOffset - startOffset)

        if distance < 0.0001 {
            sceneInput.filterOffset = targetOffset
            cancelFilterOffsetAnimation()
            return
        }

        // Duration scales with distance for a consistent snap feel.
        let clampedDuration = max(0.28, min(0.7, Double(distance) * 0.45))

        filterOffsetAnimation = FilterOffsetAnimation(
            startValue: startOffset,
            targetValue: targetOffset,
            startTime: CACurrentMediaTime(),
            duration: clampedDuration,
        )

        filterOffsetDisplayLink?.invalidate()
        let displayLink = CADisplayLink(target: self, selector: #selector(handleFilterOffsetAnimation))
        filterOffsetDisplayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    @objc
    private func handleFilterOffsetAnimation() {
        guard let animation = filterOffsetAnimation else {
            cancelFilterOffsetAnimation()
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
            cancelFilterOffsetAnimation()
            return
        }
    }

    private func calculateSnapTarget(
        currentPosition: Float,
        velocity: Float,
    ) -> Float {
        let lowerBound = floor(currentPosition)
        let upperBound = ceil(currentPosition)

        if lowerBound == upperBound {
            return lowerBound
        }

        let distanceToLower = currentPosition - lowerBound
        let distanceToUpper = upperBound - currentPosition

        let velocityThreshold: Float = 0.3
        if abs(velocity) < velocityThreshold {
            return distanceToLower < distanceToUpper ? lowerBound : upperBound
        }

        if velocity > 0 {
            return (distanceToLower < 0.15) ? lowerBound : upperBound
        }
        return (distanceToUpper < 0.15) ? upperBound : lowerBound
    }
}
