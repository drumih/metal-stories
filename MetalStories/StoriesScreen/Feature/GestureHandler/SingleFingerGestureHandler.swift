import UIKit

// MARK: - SingleFingerGestureHandler

final class SingleFingerGestureHandler {

    // MARK: Lifecycle

    init(sceneInput: SceneInput) {
        self.sceneInput = sceneInput
    }

    // MARK: Internal

    /// Describes the start and end values for a snap animation
    struct SnapAnimationSpec {
        let currentOffset: Float
        let targetOffset: Float
    }

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
        let deltaX = Float((snapshot.startPoint.x - currentPoint.x) / bounds.width)
        sceneInput.filterOffset = snapshot.initialFilterOffset + deltaX

        let currentTime = touch.timestamp
        let dt = currentTime - snapshot.lastTimestamp
        if dt > 0 {
            let velocity = Float((snapshot.lastPoint.x - currentPoint.x) / bounds.width) / Float(dt)
            snapshot.lastVelocity = velocity
        }
        snapshot.lastPoint = currentPoint
        snapshot.lastTimestamp = currentTime
        self.snapshot = snapshot
    }

    func getAnimationSpecIfPossible() -> SnapAnimationSpec? {
        guard let snapshot else { return nil }
        let currentOffset = sceneInput.filterOffset
        let velocity = snapshot.lastVelocity
        let targetOffset = Self.calculateAnimationTarget(
            currentPosition: currentOffset,
            velocity: velocity,
        )
        return .init(currentOffset: currentOffset, targetOffset: targetOffset)
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

// MARK: - Snap Animation Target Calculation

extension SingleFingerGestureHandler {

    private enum SnapConstants {
        /// Minimum velocity (in screen widths/second) to trigger momentum-based snapping
        static let velocityThreshold: Float = 0.3

        /// If already within this distance of target, snap there despite momentum
        static let proximityOverride: Float = 0.15
    }

    private static func calculateAnimationTarget(
        currentPosition: Float,
        velocity: Float,
    ) -> Float {
        // Find the two nearest snap points (integers)
        let lowerSnapPoint = floor(currentPosition)
        let upperSnapPoint = ceil(currentPosition)

        // Already at a snap point
        guard lowerSnapPoint != upperSnapPoint else {
            return lowerSnapPoint
        }

        // Calculate distances to each snap point
        let distanceToLower = currentPosition - lowerSnapPoint
        let distanceToUpper = upperSnapPoint - currentPosition

        // Low velocity: snap to nearest
        if abs(velocity) < SnapConstants.velocityThreshold {
            return distanceToLower < distanceToUpper ? lowerSnapPoint : upperSnapPoint
        }

        // High velocity: follow momentum, unless very close to opposite edge
        if velocity > 0 {
            // Swiping right (toward higher values)
            let tooCloseToLower = distanceToLower < SnapConstants.proximityOverride
            return tooCloseToLower ? lowerSnapPoint : upperSnapPoint
        } else {
            // Swiping left (toward lower values)
            let tooCloseToUpper = distanceToUpper < SnapConstants.proximityOverride
            return tooCloseToUpper ? upperSnapPoint : lowerSnapPoint
        }
    }
}
