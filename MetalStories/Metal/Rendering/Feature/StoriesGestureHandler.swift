import UIKit
import simd

final class StoriesGestureHandler: NSObject {
    
    let view: UIView
    let sceneInput: SceneInput
    
    private var initialScale: Float = 1
    private var initialRotation: Float = 0
    private var initialTranslation: SIMD2<Float> = .init(0.5, 0.5)
    
    init(
        view: UIView,
        sceneInput: SceneInput
    ) {
        self.view = view
        self.sceneInput = sceneInput
    }
    
    func setupGestureRecognizers() {
        view.isMultipleTouchEnabled = true
        
        let pinchRecognizer = UIPinchGestureRecognizer(
            target: self,
            action: #selector(handlePinch(_:))
        )
        pinchRecognizer.delegate = self
        
        let rotationRecognizer = UIRotationGestureRecognizer(
            target: self,
            action: #selector(handleRotation(_:))
        )
        rotationRecognizer.delegate = self
        
        let panRecognizer = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePan(_:))
        )
        panRecognizer.minimumNumberOfTouches = 2
        panRecognizer.maximumNumberOfTouches = 2
        panRecognizer.delegate = self
        
        view.addGestureRecognizer(pinchRecognizer)
        view.addGestureRecognizer(rotationRecognizer)
        view.addGestureRecognizer(panRecognizer)
    }
}

private extension StoriesGestureHandler {
    
    @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        guard recognizer.numberOfTouches == 2 else { return }
        updateAnchorPoint(using: recognizer)
        
        switch recognizer.state {
        case .began:
            initialScale = sceneInput.scale
        case .changed, .ended:
            let updatedScale = initialScale * Float(recognizer.scale)
            sceneInput.scale = updatedScale
        default:
            break
        }
    }
    
    @objc func handleRotation(_ recognizer: UIRotationGestureRecognizer) {
        guard recognizer.numberOfTouches == 2 else { return }
        updateAnchorPoint(using: recognizer)
        
        switch recognizer.state {
        case .began:
            initialRotation = sceneInput.rotationRadians
        case .changed, .ended:
            let updatedRotation = initialRotation - Float(recognizer.rotation)
            sceneInput.rotationRadians = updatedRotation
        default:
            break
        }
    }
    
    @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard recognizer.numberOfTouches == 2 else { return }
        updateAnchorPoint(using: recognizer)
        
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        switch recognizer.state {
        case .began:
            initialTranslation = sceneInput.translation
        case .changed, .ended:
            let translation = recognizer.translation(in: view)
            let delta = SIMD2<Float>(
                Float(translation.x / bounds.width),
                Float(-translation.y / bounds.height) // UIKit y-axis is flipped
            )
            sceneInput.translation = initialTranslation + delta
        default:
            break
        }
    }
    
    func updateAnchorPoint(using recognizer: UIGestureRecognizer) {
        guard recognizer.numberOfTouches == 2 else { return }
        let firstTouch = recognizer.location(ofTouch: 0, in: view)
        let secondTouch = recognizer.location(ofTouch: 1, in: view)
        let midpoint = CGPoint(
            x: (firstTouch.x + secondTouch.x) / 2.0,
            y: (firstTouch.y + secondTouch.y) / 2.0
        )
        
        let bounds = view.bounds
        guard bounds.width > 0, bounds.height > 0 else { return }
        
        let normalizedAnchor = SIMD2<Float>(
            Float(midpoint.x / bounds.width),
            Float(1.0 - (midpoint.y / bounds.height)) // convert UIKit coords to Metal-style coords
        )
        sceneInput.anchorPoint = normalizedAnchor
    }
}

extension StoriesGestureHandler: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
