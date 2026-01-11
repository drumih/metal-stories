import UIKit

// MARK: - TwoFingerGestureHandler

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
        guard
            let twoPoints = Self.getTwoPointsIfPossible(touches: touches, view: overlay)
        else {
            return
        }

        let newAnchor = twoPoints.normalizedAnchor
        sceneInput.didStartNewGesture(newAnchorPoint: newAnchor)

        initialValues = InitialValues(
            initialPointsDistance: twoPoints.distance,
            initialPointsAngle: twoPoints.angle,
            initialSceneScale: sceneInput.scale,
            initialSceneRotation: sceneInput.rotationRadians,
        )
    }

    func updateGesture(
        with touches: [UITouch],
        in overlay: UIView,
    ) {
        guard
            let twoPoints = Self.getTwoPointsIfPossible(touches: touches, view: overlay)
        else {
            return
        }

        if initialValues == nil {
            startGesture(with: touches, in: overlay)
        }
        guard let initialValues else { return }

        updateAnchorPoint(
            twoPoints: twoPoints
        )

        updateScale(
            twoPoints: twoPoints,
            initialValues: initialValues,
        )

        updateAngle(
            twoPoints: twoPoints,
            initialValues: initialValues,
        )
    }

    func resetTracking() {
        initialValues = nil
    }

    // MARK: Fileprivate

    fileprivate struct TwoPoints {
        let firstPoint: CGPoint
        let secondPoint: CGPoint
        let boundsSize: CGSize
    }

    // MARK: Private

    private struct InitialValues {
        let initialPointsDistance: CGFloat
        let initialPointsAngle: CGFloat

        let initialSceneScale: Float
        let initialSceneRotation: Float
    }

    private let sceneInput: SceneInput
    private var initialValues: InitialValues?

    private static func getTwoPointsIfPossible(
        touches: [UITouch],
        view: UIView,
    ) -> TwoPoints? {
        let bounds = view.bounds
        guard
            touches.count == 2,
            bounds.width > 0,
            bounds.height > 0
        else { return nil }

        let firstPoint = touches[0].location(in: view)
        let secondPoint = touches[1].location(in: view)

        return .init(
            firstPoint: firstPoint,
            secondPoint: secondPoint,
            boundsSize: bounds.size,
        )
    }

    private func updateAnchorPoint(
        twoPoints: TwoPoints
    ) {
        let newAnchorPoint = twoPoints.normalizedAnchor
        sceneInput.didUpdateAnchorPoint(newAnchorPoint)
    }

    private func updateScale(
        twoPoints: TwoPoints,
        initialValues: InitialValues,
    ) {
        let currentDistance = twoPoints.distance
        let initialDistance = initialValues.initialPointsDistance
        guard
            currentDistance > 0, initialDistance > 0
        else {
            return
        }
        let currentScaleRatio = Float(currentDistance / initialDistance)
        sceneInput.scale = initialValues.initialSceneScale * currentScaleRatio
    }

    private func updateAngle(
        twoPoints: TwoPoints,
        initialValues: InitialValues,
    ) {
        let currentAngle = twoPoints.angle
        let initialAngle = initialValues.initialPointsAngle

        let deltaAngle = Float(currentAngle - initialAngle)
        sceneInput.rotationRadians = initialValues.initialSceneRotation - deltaAngle
    }

}

extension TwoFingerGestureHandler.TwoPoints {
    fileprivate var normalizedAnchor: SIMD2<Float> {
        let midPoint = CGPoint(
            x: (firstPoint.x + secondPoint.x) / 2.0,
            y: (firstPoint.y + secondPoint.y) / 2.0,
        )
        return SIMD2<Float>(
            Float(midPoint.x / boundsSize.width),
            Float(1.0 - (midPoint.y / boundsSize.height)),
        )
    }

    fileprivate var distance: CGFloat {
        hypot(
            secondPoint.x - firstPoint.x,
            secondPoint.y - firstPoint.y,
        )
    }

    fileprivate var angle: CGFloat {
        atan2(
            secondPoint.y - firstPoint.y,
            secondPoint.x - firstPoint.x,
        )
    }
}
