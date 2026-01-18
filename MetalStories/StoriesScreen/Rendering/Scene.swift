import Metal
import simd

// MARK: - SceneInput

protocol SceneInput: AnyObject {

    var canvasAspectRatio: Float { get }

    var filterOffset: Float { get set }

    var showOriginal: Bool { get set }

    var scale: Float { get set }
    var rotationRadians: Float { get set }

    func didStartNewGesture(newAnchorPoint: SIMD2<Float>)
    func didUpdateAnchorPoint(_ anchorPoint: SIMD2<Float>)

    func reset()

    func setPreparationResult(_ preparationResult: MetalPreparationResult)
}

// MARK: - SceneOutput

protocol SceneOutput: AnyObject {
    func getRenderPassInput(
        renderingViewSize: SIMD2<Float>,
        isForSaving: Bool,
    ) -> RenderPassInput?
}

// MARK: - Scene

final class Scene {

    // MARK: Lifecycle

    init(
        canvasAspectRatio: Float,
        imageAspectModeType: ImageAspectModeType,
    ) {
        self.canvasAspectRatio = canvasAspectRatio
        self.imageAspectModeType = imageAspectModeType
    }

    // MARK: Internal

    let canvasAspectRatio: Float

    // MARK: Private

    private let imageAspectModeType: ImageAspectModeType

    private var preparationResult: MetalPreparationResult?
    private var resolvedAspectMode = ImageAspectMode.scaleAspectFit

    private var imageFilterOffset: Float = 0
    private var isShowingOriginal = false

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

    var showOriginal: Bool {
        get { isShowingOriginal }
        set { isShowingOriginal = newValue }
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
        isShowingOriginal = false

        anchorPoint = .init(0.5, 0.5)
        rotation = 0
        userScale = 1
        anchorToImageOffset = .init(repeating: 0)
    }

    func didStartNewGesture(newAnchorPoint: SIMD2<Float>) {
        let clampedAnchor = SIMD2<Float>(
            clamp01(newAnchorPoint.x),
            clamp01(newAnchorPoint.y),
        )
        anchorToImageOffset = TransformCalculator.getAnchorToImageOffset(
            currentAnchorPoint: anchorPoint,
            newAnchorPoint: clampedAnchor,
            anchorToImageOffset: anchorToImageOffset,
            rotation: rotation,
            scale: userScale,
            canvasAspectRatio: canvasAspectRatio,
        )
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

    func getRenderPassInput(
        renderingViewSize: SIMD2<Float>,
        isForSaving: Bool,
    ) -> RenderPassInput? {
        guard let preparationResult else { return nil }

        let mvpTransform = getMVPTransform(
            textureSize: preparationResult.textureSize,
            renderingViewSize: renderingViewSize,
        )
        let filterPositionOffset =
            if isForSaving {
                imageFilterOffset.rounded()
            } else {
                isShowingOriginal ? 0 : imageFilterOffset
            }
        return RenderPassInput(
            imageTexture: preparationResult.texture,
            mvpTransform: mvpTransform,
            bottomBackgroundColor: preparationResult.bottomColor,
            topBackgroundColor: preparationResult.topColor,
            filterPositionOffset: filterPositionOffset,
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
            mirroredX: false,
            aspectMode: resolvedAspectMode,
        )
    }
}
