import Metal
import simd

// MARK: - SceneInput

protocol SceneInput: AnyObject {

    var filterOffset: Float { get set }

    var scale: Float { get set } // in range 0.1 ... 3
    var rotationRadians: Float { get set } // no limits, but must be normalized on set

    func didStartNewGesture(newAnchorPoint: SIMD2<Float>)
    func didUpdateAnchorPoint(_ anchorPoint: SIMD2<Float>)

    func reset()

    func setPreparationResult(_ preparationResult: MetalPreparationResult)
}

// MARK: - SceneOutput

protocol SceneOutput: AnyObject {
    func getRenderPassInput(renderingViewSize: SIMD2<Float>) -> RenderPassInput?
}

// MARK: - Scene

final class Scene {

    private let imageAspectModeType = ImageAspectModeType.automatic(threshold: 4.0 / 5.0)
    private let canvasAspectRatio: Float = 9.0 / 16.0

    private var preparationResult: MetalPreparationResult?

    private var _textureSize: SIMD2<Float>?
    private var _resolvedAspectMode = ImageAspectMode.scaleAspectFit

    private var _filterOffset: Float = 0

    private var _scale: Float = 1
    private var _rotationRadians: Float = 0
    private var _anchorPoint = SIMD2<Float>(0.5, 0.5)
    private var _toAnchorPointVector = SIMD2<Float>(repeating: 0)
}

// MARK: SceneInput

extension Scene: SceneInput {

    // MARK: Internal

    var scale: Float {
        get { _scale }
        set { _scale = max(0.1, min(3.0, newValue)) }
    }

    var rotationRadians: Float {
        get { _rotationRadians }
        set {
            // Normalize to 0...2 * Float.pi
            let twoPi = Float.pi * 2.0
            _rotationRadians = newValue.truncatingRemainder(dividingBy: twoPi)
            if _rotationRadians < 0 {
                _rotationRadians += twoPi
            }
        }
    }

    var filterOffset: Float {
        get { _filterOffset }
        set { _filterOffset = newValue }
    }

    func setPreparationResult(_ preparationResult: MetalPreparationResult) {
        self.preparationResult = preparationResult
        let textureSize = SIMD2<Float>(
            Float(preparationResult.texture.width),
            Float(preparationResult.texture.height),
        )
        _textureSize = textureSize
        _resolvedAspectMode = Self.targetAspectMode(
            for: imageAspectModeType,
            textureSize: textureSize,
        )
    }

    func reset() {
        _anchorPoint = .init(0.5, 0.5)
        _rotationRadians = 0
        _scale = 1
        _filterOffset = 0
        _toAnchorPointVector = .init(repeating: 0)
    }

    func didStartNewGesture(newAnchorPoint: SIMD2<Float>) {
        let clampedAnchor = SIMD2<Float>(
            max(0.0, min(1.0, newAnchorPoint.x)),
            max(0.0, min(1.0, newAnchorPoint.y)),
        )
        let canvasSize = SIMD2<Float>(canvasAspectRatio, 1.0)
        let scale = _scale
        if scale > .ulpOfOne {
            let s = sin(_rotationRadians)
            let c = cos(_rotationRadians)

            let vCanvas = _toAnchorPointVector * canvasSize * scale
            let rotated = SIMD2<Float>(
                vCanvas.x * c - vCanvas.y * s,
                vCanvas.x * s + vCanvas.y * c,
            )
            let deltaAnchor = (_anchorPoint - clampedAnchor) * canvasSize
            let target = deltaAnchor + rotated

            let unrotated = SIMD2<Float>(
                target.x * c + target.y * s,
                -target.x * s + target.y * c,
            )

            _toAnchorPointVector = unrotated / (canvasSize * scale)
        }
        _anchorPoint = clampedAnchor
    }

    func didUpdateAnchorPoint(_ anchorPoint: SIMD2<Float>) {
        _anchorPoint = .init(
            max(0.0, min(1.0, anchorPoint.x)),
            max(0.0, min(1.0, anchorPoint.y)),
        )
    }

    // MARK: Private

    private static func targetAspectMode(
        for aspectModeType: ImageAspectModeType,
        textureSize: SIMD2<Float>,
    ) -> ImageAspectMode {
        switch aspectModeType {
        case .automatic(let threshold):
            let aspectRatio = textureSize.x / textureSize.y
            return aspectRatio < threshold ? .scaleAspectFill : .scaleAspectFit

        case .specific(let aspectMode):
            return aspectMode
        }
    }

}

// MARK: SceneOutput

extension Scene: SceneOutput {

    // MARK: Internal

    func getRenderPassInput(renderingViewSize: SIMD2<Float>) -> RenderPassInput? {
        guard let _textureSize, let preparationResult else { return nil }
        let transform = getTransform(
            textureSize: _textureSize,
            renderingViewSize: renderingViewSize,
        )
        return RenderPassInput(
            imageTexture: preparationResult.texture,
            transform: transform,
            bottomBackgroundColor: preparationResult.bottomColor,
            topBackgroundColor: preparationResult.topColor,
            filterPositionOffset: _filterOffset,
        )
    }

    // MARK: Private

    private func getTransform(
        textureSize: SIMD2<Float>,
        renderingViewSize: SIMD2<Float>,
    ) -> float4x4 {
        TransformCalculator.getTransform(
            textureSize: textureSize,
            canvasSize: renderingViewSize,
            anchor: _anchorPoint,
            scale: _scale,
            rotation: _rotationRadians,
            translation: _anchorPoint + _toAnchorPointVector,
            aspectMode: _resolvedAspectMode,
        )
    }
}
