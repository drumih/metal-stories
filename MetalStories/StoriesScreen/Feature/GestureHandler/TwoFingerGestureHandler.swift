import UIKit

final class TwoFingerGestureHandler {

    // MARK: Lifecycle

    init(sceneInput: SceneInput) {
        self.sceneInput = sceneInput
    }

    // MARK: Internal

    func startGesture(
        with touches: [UITouch],
        in overlay: UIView,
    ) {
        guard touches.count == 2 else { return }
        guard let firstTouch = touches.first, let secondTouch = touches.last else { return }

        let bounds = overlay.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let firstPoint = firstTouch.location(in: overlay)
        let secondPoint = secondTouch.location(in: overlay)
        let midpoint = midpoint(firstPoint, secondPoint)
        let newAnchor = normalizedAnchor(for: midpoint, bounds: bounds)

        sceneInput.didStartNewGesture(newAnchorPoint: newAnchor)

        snapshot = Snapshot(
            startAngle: angle(firstPoint, secondPoint),
            startDistance: distance(firstPoint, secondPoint),
            initialScale: sceneInput.scale,
            initialRotation: sceneInput.rotationRadians,
        )
    }

    func updateGesture(
        with touches: [UITouch],
        in overlay: UIView,
    ) {
        guard touches.count == 2 else { return }
        if snapshot == nil {
            startGesture(with: touches, in: overlay)
        }
        guard let snapshot else { return }

        let bounds = overlay.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }

        let firstTouch = touches[0]
        let secondTouch = touches[1]
        let firstPoint = firstTouch.location(in: overlay)
        let secondPoint = secondTouch.location(in: overlay)
        let midpoint = midpoint(firstPoint, secondPoint)
        let currentAnchor = normalizedAnchor(for: midpoint, bounds: bounds)

        let currentDistance = distance(firstPoint, secondPoint)
        if currentDistance > .ulpOfOne, snapshot.startDistance > .ulpOfOne {
            let scaleRatio = Float(currentDistance / snapshot.startDistance)
            sceneInput.scale = snapshot.initialScale * scaleRatio
        }

        let currentAngle = angle(firstPoint, secondPoint)
        let deltaAngle = Float(currentAngle - snapshot.startAngle)
        sceneInput.rotationRadians = snapshot.initialRotation - deltaAngle

        sceneInput.anchorPoint = currentAnchor
    }

    func resetTracking() {
        snapshot = nil
    }

    // MARK: Private

    private struct Snapshot {
        let startAngle: CGFloat
        let startDistance: CGFloat
        let initialScale: Float
        let initialRotation: Float
    }

    private let sceneInput: SceneInput
    private var snapshot: Snapshot?


    // MARK: Fileprivate

    fileprivate func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        hypot(p2.x - p1.x, p2.y - p1.y)
    }

    // MARK: Private

    private func midpoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        CGPoint(
            x: (p1.x + p2.x) / 2.0,
            y: (p1.y + p2.y) / 2.0,
        )
    }

    private func normalizedAnchor(for point: CGPoint, bounds: CGRect) -> SIMD2<Float> {
        SIMD2<Float>(
            Float(point.x / bounds.width),
            Float(1.0 - (point.y / bounds.height)),
        )
    }

    private func angle(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        atan2(p2.y - p1.y, p2.x - p1.x)
    }
}
