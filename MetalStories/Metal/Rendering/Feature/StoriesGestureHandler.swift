import UIKit
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
    }
    
    let sceneInput: SceneInput
    
    private weak var touchOverlay: TouchTrackingView?
    private var trackedTouches: [UITouch] = []
    private var twoFingerGestureSnapshot: TwoFingerGestureSnapshot?
    private var singleFingerGestureSnapshot: SingleFingerGestureSnapshot?
    
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
        singleFingerGestureSnapshot = SingleFingerGestureSnapshot(
            startPoint: touch.location(in: overlay),
            initialFilterOffset: sceneInput.filterOffset
        )
    }
    
    func updateSingleFingerGesture(in overlay: UIView) {
        guard trackedTouches.count == 1 else { return }
        guard let touch = trackedTouches.first else { return }
        if singleFingerGestureSnapshot == nil {
            startSingleFingerGesture(in: overlay)
        }
        guard let snapshot = singleFingerGestureSnapshot else { return }
        
        let bounds = overlay.bounds
        guard bounds.width > 0 else { return }
        
        let currentPoint = touch.location(in: overlay)
        let deltaX = Float((currentPoint.x - snapshot.startPoint.x) / bounds.width)
        sceneInput.filterOffset = snapshot.initialFilterOffset + deltaX
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
        trackedTouches.removeAll { touch in
            touches.contains(where: { $0 === touch })
        }
        
        switch trackedTouches.count {
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
        resetSnapshots()
        trackedTouches.removeAll()
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
