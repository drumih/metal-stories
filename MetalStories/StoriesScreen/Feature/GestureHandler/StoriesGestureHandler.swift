import QuartzCore
import simd
import UIKit

// MARK: - TouchTrackingViewDelegate

private protocol TouchTrackingViewDelegate: AnyObject {
    func touchView(_ view: UIView, touchesBegan touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesMoved touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesEnded touches: Set<UITouch>, with event: UIEvent?)
    func touchView(_ view: UIView, touchesCancelled touches: Set<UITouch>, with event: UIEvent?)
}

// MARK: - StoriesGestureHandler

final class StoriesGestureHandler {

    // MARK: Lifecycle

    init(
        touchTrackingView: TouchTrackingView,
        sceneInput: SceneInput,
    ) {
        self.sceneInput = sceneInput
        singleFingerHandler = .init(sceneInput: sceneInput)
        twoFingerHandler = .init(sceneInput: sceneInput)
        offsetAnimator = .init(sceneInput: sceneInput)

        touchTrackingView.touchDelegate = self
    }

    // MARK: Internal

    let sceneInput: SceneInput

    weak var offsetAnimatorDelegate: OffsetAnimatorDelegate? {
        get { offsetAnimator.delegate }
        set { offsetAnimator.delegate = newValue }
    }

    func resetTracking() {
        trackedTouches.removeAll()

        offsetAnimator.cancel()
        singleFingerHandler.resetTracking()
        twoFingerHandler.resetTracking()
    }

    // MARK: Private

    private var trackedTouches = [UITouch]()
    private let singleFingerHandler: SingleFingerGestureHandler
    private let twoFingerHandler: TwoFingerGestureHandler
    private let offsetAnimator: OffsetAnimator

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
            offsetAnimator.cancel()
            twoFingerHandler.resetTracking()
            let touch = trackedTouches[0]
            singleFingerHandler.startGesture(with: touch, in: view)

        case 2:
            if singleFingerHandler.isGestureActive, let animationSpec = singleFingerHandler.getAnimationSpecIfPossible() {
                offsetAnimator.animate(from: animationSpec.currentOffset, to: animationSpec.targetOffset)
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
            let touch = trackedTouches[0]
            singleFingerHandler.updateGesture(with: touch, in: view)
            offsetAnimator.cancel()

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
        if wasSingleFingerGesture, remainingTouches == 0, let animationSpec = singleFingerHandler.getAnimationSpecIfPossible() {
            offsetAnimator.animate(from: animationSpec.currentOffset, to: animationSpec.targetOffset)
        }

        switch remainingTouches {
        case 0, 1:
            // All touches lifted or only one remains - reset both handlers
            twoFingerHandler.resetTracking()
            singleFingerHandler.resetTracking()

        case 2:
            // Dropped back to two fingers from three+ (edge case)
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
