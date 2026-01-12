import Metal
import simd

// MARK: - SceneInput

protocol SceneInput: AnyObject {

    var canvasAspectRatio: Float { get }

    var filterOffset: Float { get set }

    var scale: Float { get set }
    var rotationRadians: Float { get set }

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
    
    init(
        canvasAspectRatio: Float,
        imageAspectModeType: ImageAspectModeType,
    ) {
        self.canvasAspectRatio = canvasAspectRatio
        self.imageAspectModeType = imageAspectModeType
    }

    let canvasAspectRatio: Float

    private let imageAspectModeType: ImageAspectModeType

    private var preparationResult: MetalPreparationResult?
    private var resolvedAspectMode = ImageAspectMode.scaleAspectFit

    private var imageFilterOffset: Float = 0

    private var userScale: Float = 1
    private var rotation: Float = 0
    private var anchorPoint = SIMD2<Float>(0.5, 0.5)
    private var anchorToImageOffset = SIMD2<Float>(repeating: 0)
}

// MARK: SceneInput

extension Scene: SceneInput {

    // MARK: Internal

    var scale: Float {
        get { userScale }
        set { userScale = clamp(value: newValue, min: 0.1, max: 3.0) }
    }

    var rotationRadians: Float {
        get { rotation }
        set {
            let twoPi = Float.pi * 2.0
            rotation = newValue.truncatingRemainder(dividingBy: twoPi)
            if rotation < 0 {
                rotation += twoPi
            }
        }
    }

    var filterOffset: Float {
        get { imageFilterOffset }
        set { imageFilterOffset = newValue }
    }

    func setPreparationResult(_ preparationResult: MetalPreparationResult) {
        self.preparationResult = preparationResult
        resolvedAspectMode = Self.targetAspectMode(
            for: imageAspectModeType,
            textureSize: preparationResult.textureSize,
        )
    }

    func reset() {
        imageFilterOffset = 0
        
        anchorPoint = .init(0.5, 0.5)
        rotation = 0
        userScale = 1
        anchorToImageOffset = .init(repeating: 0)
    }

    func didStartNewGesture(newAnchorPoint: SIMD2<Float>) {
        // TODO: extract it to TransformCalculator, clean up
        
        let clampedAnchor = SIMD2<Float>(
            clamp01(newAnchorPoint.x),
            clamp01(newAnchorPoint.y)
        )
        let canvasSize = SIMD2<Float>(1.0, canvasAspectRatio)
        let scale = userScale
        if scale > 0 {
            // TODO: improve this code it somehow
            let s = sin(rotation)
            let c = cos(rotation)

            let vCanvas = anchorToImageOffset * canvasSize * scale
            let rotated = SIMD2<Float>(
                vCanvas.x * c - vCanvas.y * s,
                vCanvas.x * s + vCanvas.y * c,
            )
            let deltaAnchor = (anchorPoint - clampedAnchor) * canvasSize
            let target = deltaAnchor + rotated

            let unrotated = SIMD2<Float>(
                target.x * c + target.y * s,
                -target.x * s + target.y * c,
            )

            // TODO: use _toAnchorPointVector of _fromAnchorPointVector
            anchorToImageOffset = unrotated / (canvasSize * scale)
        }
        anchorPoint = clampedAnchor
    }

    func didUpdateAnchorPoint(_ anchorPoint: SIMD2<Float>) {
        self.anchorPoint = .init(
            clamp01(anchorPoint.x),
            clamp01(anchorPoint.y),
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
        guard let preparationResult else { return nil }

        let mvpTransform = getMVPTransform(
            textureSize: preparationResult.textureSize,
            renderingViewSize: renderingViewSize,
        )

        return RenderPassInput(
            imageTexture: preparationResult.texture,
            mvpTransform: mvpTransform,
            bottomBackgroundColor: preparationResult.bottomColor,
            topBackgroundColor: preparationResult.topColor,
            filterPositionOffset: imageFilterOffset,
        )
    }

    // MARK: Private

    private func getMVPTransform(
        textureSize: SIMD2<Float>,
        renderingViewSize: SIMD2<Float>,
    ) -> float4x4 {
        TransformCalculator.getMVPTransform(
            textureSize: textureSize,
            canvasSize: renderingViewSize,
            anchorPoint: anchorPoint,
            anchorToImageOffset: anchorToImageOffset,
            rotation: rotation,
            scale: userScale,
            aspectMode: resolvedAspectMode
        )
    }
}
