import QuartzCore
import simd
import UIKit


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

    func resetTracking() {
        trackedTouches.removeAll()
        singleFingerHandler.cancelAnimations()
        singleFingerHandler.resetTracking()
        twoFingerHandler.resetTracking()
    }

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
            if singleFingerHandler.isGestureActive {
                singleFingerHandler.snapOffsetIfNeeded()
            }
            singleFingerHandler.resetTracking()
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
