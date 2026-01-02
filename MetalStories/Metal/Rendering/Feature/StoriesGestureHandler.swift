import UIKit
import QuartzCore
import simd

// TODO: Improve it
final class StoriesGestureHandler {
    
    private struct TwoFingerGestureSnapshot {
        let startMidpoint: SIMD2<Float>
        let startAngle: CGFloat
        let startDistance: CGFloat
        let initialScale: Float
        let initialRotation: Float
        let initialTranslation: SIMD2<Float>
    }
    
    private struct SingleFingerGestureSnapshot {
        let startPoint: CGPoint
        let initialFilterOffset: Float
        var lastPoint: CGPoint
        var lastTimestamp: TimeInterval
        var lastVelocity: Float
        var lastAcceleration: Float
    }
    
    let sceneInput: SceneInput
    
    private weak var touchOverlay: TouchTrackingView?
    private var trackedTouches: [UITouch] = []
    private var twoFingerGestureSnapshot: TwoFingerGestureSnapshot?
    private var singleFingerGestureSnapshot: SingleFingerGestureSnapshot?
    
    private struct FilterOffsetAnimation {
        let startValue: Float
        let targetValue: Float
        let startTime: CFTimeInterval
        let duration: CFTimeInterval
    }
    
    private var filterOffsetAnimation: FilterOffsetAnimation?
    private var filterOffsetDisplayLink: CADisplayLink?
    
    init(
        touchTrackingView: TouchTrackingView,
        sceneInput: SceneInput
    ) {
        self.touchOverlay = touchTrackingView
        self.sceneInput = sceneInput

        touchTrackingView.touchDelegate = self
    }
}

private extension StoriesGestureHandler {
    
    func startTwoFingerGesture(in overlay: UIView) {
        guard trackedTouches.count == 2 else { return }
        guard let firstTouch = trackedTouches.first, let secondTouch = trackedTouches.last else { return }
        cancelFilterOffsetAnimation()
        
        let bounds = overlay.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        let firstPoint = firstTouch.location(in: overlay)
        let secondPoint = secondTouch.location(in: overlay)
        let midpoint = midpoint(firstPoint, secondPoint)
        let newAnchor = normalizedAnchor(for: midpoint, bounds: bounds)
        let canvasSize = SIMD2<Float>(Float(bounds.width), Float(bounds.height))
        
        rebaseTranslationForAnchorChange(
            newAnchor: newAnchor,
            canvasSize: canvasSize
        )
        sceneInput.anchorPoint = newAnchor
        
        twoFingerGestureSnapshot = TwoFingerGestureSnapshot(
            startMidpoint: newAnchor,
            startAngle: angle(firstPoint, secondPoint),
            startDistance: distance(firstPoint, secondPoint),
            initialScale: sceneInput.scale,
            initialRotation: sceneInput.rotationRadians,
            initialTranslation: sceneInput.translation
        )
    }
    
    func updateTwoFingerGesture(in overlay: UIView) {
        guard trackedTouches.count == 2 else { return }
        guard let firstTouch = trackedTouches.first, let secondTouch = trackedTouches.last else { return }
        if twoFingerGestureSnapshot == nil {
            startTwoFingerGesture(in: overlay)
        }
        guard let snapshot = twoFingerGestureSnapshot else { return }
        
        let bounds = overlay.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
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
    
    func startSingleFingerGesture(in overlay: UIView) {
        guard trackedTouches.count == 1 else { return }
        guard let touch = trackedTouches.first else { return }
        cancelFilterOffsetAnimation()
        let startPoint = touch.location(in: overlay)
        singleFingerGestureSnapshot = SingleFingerGestureSnapshot(
            startPoint: startPoint,
            initialFilterOffset: sceneInput.filterOffset,
            lastPoint: startPoint,
            lastTimestamp: touch.timestamp,
            lastVelocity: 0,
            lastAcceleration: 0
        )
    }
    
    func updateSingleFingerGesture(in overlay: UIView) {
        guard trackedTouches.count == 1 else { return }
        guard let touch = trackedTouches.first else { return }
        if singleFingerGestureSnapshot == nil {
            startSingleFingerGesture(in: overlay)
        }
        guard var snapshot = singleFingerGestureSnapshot else { return }
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
        singleFingerGestureSnapshot = snapshot
    }

    func snapSingleFingerOffsetIfNeeded() {
        guard let snapshot = singleFingerGestureSnapshot else { return }
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
        var targetOffset: Float
        if projectedOffset == lower || projectedOffset == upper {
            targetOffset = projectedOffset
        } else {
            targetOffset = projectedOffset < midpoint ? lower : upper
        }
        
        startFilterOffsetAnimation(
            to: targetOffset,
            initialVelocity: velocity
        )
    }
    
    func resetSnapshots() {
        twoFingerGestureSnapshot = nil
        singleFingerGestureSnapshot = nil
    }
    
    func normalizedAnchor(for point: CGPoint, bounds: CGRect) -> SIMD2<Float> {
        SIMD2<Float>(
            Float(point.x / bounds.width),
            Float(1.0 - (point.y / bounds.height))
        )
    }
    
    func midpoint(_ p1: CGPoint, _ p2: CGPoint) -> CGPoint {
        CGPoint(
            x: (p1.x + p2.x) / 2.0,
            y: (p1.y + p2.y) / 2.0
        )
    }
    
    func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        hypot(p2.x - p1.x, p2.y - p1.y)
    }
    
    func angle(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        atan2(p2.y - p1.y, p2.x - p1.x)
    }
    
    func rebaseTranslationForAnchorChange(
        newAnchor: SIMD2<Float>,
        canvasSize: SIMD2<Float>
    ) {
        let previousAnchor = sceneInput.anchorPoint
        guard previousAnchor != newAnchor else { return }
        
        let rotation = sceneInput.rotationRadians
        let scale = sceneInput.scale
        let cosR = cos(rotation)
        let sinR = sin(rotation)
        
        let transformMatrix = float2x2(
            SIMD2<Float>(cosR * scale, sinR * scale),
            SIMD2<Float>(-sinR * scale, cosR * scale)
        )
        let identity = float2x2(diagonal: SIMD2<Float>(1, 1))
        
        let anchorDelta = (previousAnchor - newAnchor) * canvasSize
        let correction = (identity - transformMatrix) * anchorDelta
        
        let currentTranslation = (sceneInput.translation - 0.5) * canvasSize
        let updatedTranslation = currentTranslation + correction
        sceneInput.translation = (updatedTranslation / canvasSize) + 0.5
    }
    
    func cancelFilterOffsetAnimation() {
        filterOffsetDisplayLink?.invalidate()
        filterOffsetDisplayLink = nil
        filterOffsetAnimation = nil
    }
    
    func startFilterOffsetAnimation(
        to targetOffset: Float,
        initialVelocity: Float
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
            duration: clampedDuration
        )
        
        filterOffsetDisplayLink?.invalidate()
        let displayLink = CADisplayLink(target: self, selector: #selector(handleFilterOffsetAnimation))
        filterOffsetDisplayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }
    
    @objc
    func handleFilterOffsetAnimation() {
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

extension StoriesGestureHandler: TouchTrackingViewDelegate {
    func touchView(
        _ view: UIView,
        touchesBegan touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        for touch in touches where trackedTouches.count < 2 {
            guard !trackedTouches.contains(where: { $0 === touch }) else { continue }
            trackedTouches.append(touch)
        }
        
        switch trackedTouches.count {
        case 1:
            twoFingerGestureSnapshot = nil
            startSingleFingerGesture(in: view)
        case 2:
            singleFingerGestureSnapshot = nil
            startTwoFingerGesture(in: view)
        default:
            break
        }
    }
    
    func touchView(
        _ view: UIView,
        touchesMoved touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        switch trackedTouches.count {
        case 1:
            updateSingleFingerGesture(in: view)
        case 2:
            updateTwoFingerGesture(in: view)
        default:
            break
        }
    }
    
    func touchView(
        _ view: UIView,
        touchesEnded touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        guard !trackedTouches.isEmpty else { return }
        let wasSingleFingerGesture = trackedTouches.count == 1 && singleFingerGestureSnapshot != nil
        trackedTouches.removeAll { touch in
            touches.contains(where: { $0 === touch })
        }
        
        let remainingTouches = trackedTouches.count
        if wasSingleFingerGesture && remainingTouches == 0 {
            snapSingleFingerOffsetIfNeeded()
        }
        
        switch remainingTouches {
        case 0:
            resetSnapshots()
        case 1:
            twoFingerGestureSnapshot = nil
            singleFingerGestureSnapshot = nil
        case 2:
            singleFingerGestureSnapshot = nil
        default:
            break
        }
    }
    
    func touchView(
        _ view: UIView,
        touchesCancelled touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        touchView(view, touchesEnded: touches, with: event)
    }
}

private protocol TouchTrackingViewDelegate: AnyObject {
    func touchView(_ view: UIView, touchesBegan touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesMoved touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesEnded touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesCancelled touches: Set<UITouch>, with event: UIEvent?)
}

final class TouchTrackingView: UIView {
    fileprivate weak var touchDelegate: TouchTrackingViewDelegate?
    
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
}
