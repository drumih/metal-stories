import QuartzCore
import simd
import UIKit

// MARK: - SingleFingerGestureHandler

// TODO: more responsive swipe for single gesture
// TODO: finish single gesture the moment two fingers gesture started

private final class SingleFingerGestureHandler {

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
            lastAcceleration: 0,
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
            let acceleration = (velocity - snapshot.lastVelocity) / Float(dt)
            snapshot.lastAcceleration = acceleration
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
        let acceleration = snapshot.lastAcceleration

        let lower = floor(currentOffset)
        let upper = lower + 1
        let midpoint = lower + 0.5

        let projectedOffset = currentOffset
            + velocity * 0.25 // increased inertia so smaller swipes can cross midpoint
            + acceleration * 0.07 // acceleration nudges the snap direction

        // Snap strictly to the nearest neighbor; inertia only influences which side of the midpoint we land on.
        let targetOffset: Float =
            if projectedOffset == lower || projectedOffset == upper {
                projectedOffset
            } else {
                projectedOffset < midpoint ? lower : upper
            }

        startFilterOffsetAnimation(
            to: targetOffset,
            initialVelocity: velocity,
        )
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
        var lastAcceleration: Float
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

}

extension SingleFingerGestureHandler {
    private func cancelFilterOffsetAnimation() {
        filterOffsetDisplayLink?.invalidate()
        filterOffsetDisplayLink = nil
        filterOffsetAnimation = nil
    }

    private func startFilterOffsetAnimation(
        to targetOffset: Float,
        initialVelocity: Float,
    ) {
        let startOffset = sceneInput.filterOffset
        let distance = abs(targetOffset - startOffset)

        if distance < 0.0001 {
            sceneInput.filterOffset = targetOffset
            cancelFilterOffsetAnimation()
            return
        }

        // Duration scales with distance and velocity to feel smooth.
        let velocityComponent = max(0.1, min(1.0, Double(abs(initialVelocity)) * 0.5))
        let baseDuration = 0.16 + 0.18 * velocityComponent
        let distanceComponent = Double(distance) * 0.25
        let clampedDuration = max(0.16, min(0.45, baseDuration + distanceComponent))

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
        let eased = 1.0 - pow(1.0 - progress, 3)
        let newOffset = animation.startValue + Float(eased) * (animation.targetValue - animation.startValue)
        sceneInput.filterOffset = newOffset

        if progress >= 1.0 {
            sceneInput.filterOffset = animation.targetValue
            cancelFilterOffsetAnimation()
            return
        }
    }
}

// MARK: - TwoFingerGestureHandler

private final class TwoFingerGestureHandler {

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
        let canvasSize = SIMD2<Float>(Float(bounds.width), Float(bounds.height))

        rebaseTranslationForAnchorChange(
            newAnchor: newAnchor,
            canvasSize: canvasSize,
        )
        sceneInput.anchorPoint = newAnchor

        snapshot = Snapshot(
            startMidpoint: newAnchor,
            startAngle: angle(firstPoint, secondPoint),
            startDistance: distance(firstPoint, secondPoint),
            initialScale: sceneInput.scale,
            initialRotation: sceneInput.rotationRadians,
            initialTranslation: sceneInput.translation,
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

        let translationDelta = currentAnchor - snapshot.startMidpoint
        sceneInput.translation = snapshot.initialTranslation + translationDelta

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
        let startMidpoint: SIMD2<Float>
        let startAngle: CGFloat
        let startDistance: CGFloat
        let initialScale: Float
        let initialRotation: Float
        let initialTranslation: SIMD2<Float>
    }

    private let sceneInput: SceneInput
    private var snapshot: Snapshot?

}

extension TwoFingerGestureHandler {

    // MARK: Fileprivate

    fileprivate func midpoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        CGPoint(
            x: (p1.x + p2.x) / 2.0,
            y: (p1.y + p2.y) / 2.0,
        )
    }

    fileprivate func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        hypot(p2.x - p1.x, p2.y - p1.y)
    }

    // MARK: Private

    private func normalizedAnchor(for point: CGPoint, bounds: CGRect) -> SIMD2<Float> {
        SIMD2<Float>(
            Float(point.x / bounds.width),
            Float(1.0 - (point.y / bounds.height)),
        )
    }

    private func angle(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        atan2(p2.y - p1.y, p2.x - p1.x)
    }

    private func rebaseTranslationForAnchorChange(
        newAnchor: SIMD2<Float>,
        canvasSize: SIMD2<Float>,
    ) {
        let previousAnchor = sceneInput.anchorPoint
        guard previousAnchor != newAnchor else { return }

        let rotation = sceneInput.rotationRadians
        let scale = sceneInput.scale
        let cosR = cos(rotation)
        let sinR = sin(rotation)

        let transformMatrix = float2x2(
            SIMD2<Float>(cosR * scale, sinR * scale),
            SIMD2<Float>(-sinR * scale, cosR * scale),
        )
        let identity = float2x2(diagonal: SIMD2<Float>(1, 1))

        let anchorDelta = (previousAnchor - newAnchor) * canvasSize
        let correction = (identity - transformMatrix) * anchorDelta

        let currentTranslation = (sceneInput.translation - 0.5) * canvasSize
        let updatedTranslation = currentTranslation + correction
        sceneInput.translation = (updatedTranslation / canvasSize) + 0.5
    }
}

// MARK: - StoriesGestureHandler

// TODO: Improve it
final class StoriesGestureHandler {

    // MARK: Lifecycle

    init(
        touchTrackingView: TouchTrackingView,
        sceneInput: SceneInput,
    ) {
        self.sceneInput = sceneInput
        singleFingerHandler = SingleFingerGestureHandler(sceneInput: sceneInput)
        twoFingerHandler = TwoFingerGestureHandler(sceneInput: sceneInput)

        touchTrackingView.touchDelegate = self
    }

    // MARK: Internal

    let sceneInput: SceneInput

    // MARK: Private

    private var trackedTouches = [UITouch]()
    private let singleFingerHandler: SingleFingerGestureHandler
    private let twoFingerHandler: TwoFingerGestureHandler

}

// MARK: TouchTrackingViewDelegate

extension StoriesGestureHandler: TouchTrackingViewDelegate {
    func touchView(
        _ view: UIView,
        touchesBegan touches: Set<UITouch>,
        with _: UIEvent?,
    ) {
        for touch in touches where trackedTouches.count < 2 {
            guard !trackedTouches.contains(where: { $0 === touch }) else { continue }
            trackedTouches.append(touch)
        }

        switch trackedTouches.count {
        case 1:
            twoFingerHandler.resetTracking()
            guard let touch = trackedTouches.first else { return }
            singleFingerHandler.startGesture(with: touch, in: view)

        case 2:
            singleFingerHandler.resetTracking()
            singleFingerHandler.cancelAnimations()
            twoFingerHandler.startGesture(with: trackedTouches, in: view)

        default:
            break
        }
    }

    func touchView(
        _ view: UIView,
        touchesMoved _: Set<UITouch>,
        with _: UIEvent?,
    ) {
        switch trackedTouches.count {
        case 1:
            guard let touch = trackedTouches.first else { return }
            singleFingerHandler.updateGesture(with: touch, in: view)

        case 2:
            twoFingerHandler.updateGesture(with: trackedTouches, in: view)

        default:
            break
        }
    }

    func touchView(
        _: UIView,
        touchesEnded touches: Set<UITouch>,
        with _: UIEvent?,
    ) {
        guard !trackedTouches.isEmpty else { return }
        let wasSingleFingerGesture = trackedTouches.count == 1 && singleFingerHandler.isGestureActive
        trackedTouches.removeAll { touch in
            touches.contains(where: { $0 === touch })
        }

        let remainingTouches = trackedTouches.count
        if wasSingleFingerGesture, remainingTouches == 0 {
            singleFingerHandler.snapOffsetIfNeeded()
        }

        switch remainingTouches {
        case 0:
            twoFingerHandler.resetTracking()
            singleFingerHandler.resetTracking()

        case 1:
            twoFingerHandler.resetTracking()
            singleFingerHandler.resetTracking()

        case 2:
            singleFingerHandler.resetTracking()

        default:
            break
        }
    }

    func touchView(
        _ view: UIView,
        touchesCancelled touches: Set<UITouch>,
        with event: UIEvent?,
    ) {
        touchView(view, touchesEnded: touches, with: event)
    }
}

// MARK: - TouchTrackingViewDelegate

private protocol TouchTrackingViewDelegate: AnyObject {
    func touchView(_ view: UIView, touchesBegan touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesMoved touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesEnded touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesCancelled touches: Set<UITouch>, with event: UIEvent?)
}

// MARK: - TouchTrackingView

final class TouchTrackingView: UIView {

    // MARK: Internal

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDelegate?.touchView(self, touchesBegan: touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDelegate?.touchView(self, touchesMoved: touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDelegate?.touchView(self, touchesEnded: touches, with: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDelegate?.touchView(self, touchesCancelled: touches, with: event)
    }

    // MARK: Fileprivate

    fileprivate weak var touchDelegate: TouchTrackingViewDelegate?

}
