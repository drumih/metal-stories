import UIKit

final class SingleFingerGestureHandler {
    
    struct AnimationPositions {
        let from: Float
        let to: Float
    }
    
    // MARK: Lifecycle
    
    init(sceneInput: SceneInput) {
        self.sceneInput = sceneInput
    }
    
    // MARK: Internal
    
    var isGestureActive: Bool {
        snapshot != nil
    }
    
    func startGesture(
        with touch: UITouch,
        in overlay: UIView,
    ) {
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
    
    func getAnimationSpecIfPossible() -> AnimationPositions? {
        guard let snapshot else { return nil }
        let currentOffset = sceneInput.filterOffset
        let velocity = snapshot.lastVelocity
        let targetOffset = Self.calculateAnimationTarget(
            currentPosition: currentOffset,
            velocity: velocity,
        )
        return .init(from: currentOffset, to: targetOffset)
    }
    
    func resetTracking() {
        snapshot = nil
    }
    
    // MARK: Private
    
    private struct Snapshot {
        let startPoint: CGPoint
        let initialFilterOffset: Float
        var lastPoint: CGPoint
        var lastTimestamp: TimeInterval
        var lastVelocity: Float
    }
    
    private let sceneInput: SceneInput
    private var snapshot: Snapshot?
}

private extension SingleFingerGestureHandler {

    static func calculateAnimationTarget(
        currentPosition: Float,
        velocity: Float,
    ) -> Float {
        let lowerBound = floor(currentPosition)
        let upperBound = ceil(currentPosition)

        guard lowerBound != upperBound else { return lowerBound }

        let distanceToLower = currentPosition - lowerBound
        let distanceToUpper = upperBound - currentPosition

        let velocityThreshold: Float = 0.3
        if abs(velocity) < velocityThreshold {
            return distanceToLower < distanceToUpper ? lowerBound : upperBound
        } else {
            if velocity > 0 {
                return (distanceToLower < 0.15) ? lowerBound : upperBound
            } else {
                return (distanceToUpper < 0.15) ? upperBound : lowerBound
            }
        }
    }
}
