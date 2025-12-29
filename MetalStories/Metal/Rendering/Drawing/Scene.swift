import simd
import Metal

protocol SceneInput {
    func setPreparationResult(_ preparationResult: MetalPreparationResult)
    
    var scale: Float { get set } // in range 0.1 ... 3
    var rotationRadians: Float { get set } // no limits, but must be normalized on set
    var translation: SIMD2<Float> { get set } // -1...2
    var anchorPoint: SIMD2<Float> { get set } // in range 0...1
}

protocol SceneOutput {
    func getRenderPassInput(renderingViewSize: SIMD2<Float>) -> RenderPassInput?
}

final class Scene {
    
    private var preparationResult: MetalPreparationResult?

    private var _scale: Float = 1
    private var _rotationRadians: Float = 0
    private var _translation: SIMD2<Float> = .init(0.5, 0.5)
    private var _anchorPoint: SIMD2<Float> = .init(0.5, 0.5)
}

extension Scene: SceneInput {
    func setPreparationResult(_ preparationResult: MetalPreparationResult) {
        self.preparationResult = preparationResult
    }
    
    var scale: Float {
        get {
            return _scale
        }
        set {
            _scale = max(0.1, min(3.0, newValue))
        }
    }
    
    var rotationRadians: Float {
        get {
            return _rotationRadians
        }
        set {
            // Normalize to 0...2π
            let twoPi = Float.pi * 2.0
            _rotationRadians = newValue.truncatingRemainder(dividingBy: twoPi)
            if _rotationRadians < 0 {
                _rotationRadians += twoPi
            }
        }
    }
    
    var translation: SIMD2<Float> {
        get {
            return _translation
        }
        set {
            _translation = SIMD2<Float>(
                max(-1.0, min(2.0, newValue.x)),
                max(-1.0, min(2.0, newValue.y))
            )
        }
    }
    
    var anchorPoint: SIMD2<Float> {
        get {
            return _anchorPoint
        }
        set {
            _anchorPoint = SIMD2<Float>(
                max(0.0, min(1.0, newValue.x)),
                max(0.0, min(1.0, newValue.y))
            )
        }
    }
}

extension Scene: SceneOutput {
    func getRenderPassInput(
        renderingViewSize: SIMD2<Float>
    ) -> RenderPassInput? {
        guard let preparationResult else { return nil }
        let textureSize = SIMD2<Float>(
            Float(preparationResult.texture.width),
            Float(preparationResult.texture.height)
        )
        let transform = getTransform(
            textureSize: textureSize,
            renderingViewSize: renderingViewSize
        )
        return RenderPassInput(
            texture: preparationResult.texture,
            transform: transform,
            bottomBackgroundColor: .init(preparationResult.bottomColor, 1),
            topBackgroundColor: .init(preparationResult.topColor, 1)
        )
    }

    private func getTransform(
        textureSize: SIMD2<Float>,
        renderingViewSize: SIMD2<Float>
    ) -> float4x4 {
        TransformCalculator.getTransform(
            textureSize: textureSize,
            canvasSize: renderingViewSize,
            anchor: anchorPoint,
            scale: scale,
            rotation: rotationRadians,
            translation: translation,
            flipVertically: false,
            mirror: false,
            aspectMode: .default//.default
        )
    }
}
