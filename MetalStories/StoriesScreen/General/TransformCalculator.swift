import simd

// MARK: - ImageAspectMode

enum ImageAspectMode {
    case scaleAspectFit
    case scaleAspectFill
}

// MARK: - ImageAspectModeType

enum ImageAspectModeType {
    case automatic(threshold: Float)
    case specific(aspectMode: ImageAspectMode)
}

// MARK: - TransformCalculator

enum TransformCalculator {

    static func getUVTransform(
        rotationRadians: Float,
        isMirrored: Bool,
        isFlipped: Bool = false,
    ) -> float4x4 {
        let mirrorAndFlipScale = SIMD2<Float>(
            isMirrored ? -1 : 1,
            isFlipped ? -1 : 1,
        )

        let rotationMatrix = getRotationMatrixZ(rotationRadians)
        let mirrorAndFlipMatrix = getScaleMatrix(mirrorAndFlipScale)

        let transformMatrices = [
            rotationMatrix,
            mirrorAndFlipMatrix,
        ]
        return combineMatrices(transformMatrices)
    }

    static func getMVPTransform(
        textureSize: SIMD2<Float>,
        canvasSize: SIMD2<Float>,
        anchorPoint: SIMD2<Float>,
        anchorToImageOffset: SIMD2<Float>,
        rotation: Float,
        scale: Float,
        aspectMode: ImageAspectMode,
    ) -> float4x4 {
        let modelTransform = Self.getModelTransform(
            textureSize: textureSize,
            canvasSize: canvasSize,
            anchorPoint: anchorPoint,
            anchorToImageOffset: anchorToImageOffset,
            rotation: rotation,
            scale: scale,
            aspectMode: aspectMode,
        )
        let viewTransform = getViewTransform()
        let projectionTransform = getProjectionTransform(canvasSize: canvasSize)

        return projectionTransform * viewTransform * modelTransform
    }

    static func getFlippedVerticallyTransform() -> float4x4 {
        getScaleMatrix(.init(x: 1, y: -1))
    }

    static func getIdentityTransform() -> float4x4 {
        matrix_identity_float4x4
    }

    static func getZPlaneTransform(_ zOffset: Float) -> float4x4 {
        getTranslationMatrix(.init(0, 0, zOffset))
    }

    static func getAnchorToImageOffset(
        currentAnchorPoint: SIMD2<Float>,
        newAnchorPoint: SIMD2<Float>,
        anchorToImageOffset: SIMD2<Float>,
        rotation: Float,
        scale: Float,
        canvasAspectRatio: Float,
    ) -> SIMD2<Float> {
        guard scale > 0 else {
            assertionFailure()
            return anchorToImageOffset
        }
        let canvasSize = SIMD2<Float>(1.0, canvasAspectRatio)

        let scaledCanvasSize = canvasSize * scale
        let inverseCanvasScale = SIMD2<Float>.one / scaledCanvasSize

        let rotationMatrix = getRotationMatrixZ(rotation)
        let inverseRotationMatrix = getRotationMatrixZ(-rotation)
        let scaleMatrix = getScaleMatrix(scaledCanvasSize)
        let inverseScaleMatrix = getScaleMatrix(inverseCanvasScale)

        let deltaAnchor = (currentAnchorPoint - newAnchorPoint) * canvasSize
        let deltaAnchorMatrix = getTranslationMatrix(.init(deltaAnchor, 0))

        let transformMatrices = [
            scaleMatrix,
            rotationMatrix,
            deltaAnchorMatrix,
            inverseRotationMatrix,
            inverseScaleMatrix,
        ]
        let transformMatrix = combineMatrices(transformMatrices)
        let result = transformMatrix * SIMD4<Float>(anchorToImageOffset.x, anchorToImageOffset.y, 0, 1)
        return SIMD2<Float>(result.x, result.y)
    }
}

extension TransformCalculator {
    private static func getModelTransform(
        textureSize: SIMD2<Float>,
        canvasSize: SIMD2<Float>,
        anchorPoint: SIMD2<Float>,
        anchorToImageOffset: SIMD2<Float>,
        rotation: Float,
        scale: Float,
        aspectMode: ImageAspectMode,
    ) -> float4x4 {
        let aspectScale = getAspectScale(
            canvasSize: canvasSize,
            textureSize: textureSize,
            aspectMode: aspectMode,
        )
        let scaledTextureSize = textureSize * aspectScale

        let targetPosition = (anchorPoint + anchorToImageOffset - 0.5) * canvasSize
        let anchorOffset = anchorToImageOffset * canvasSize

        let userScaleMatrix = getScaleMatrix(.init(scale, scale))
        let baseScaleMatrix = getScaleMatrix(scaledTextureSize / 2.0)
        let rotationMatrix = getRotationMatrixZ(rotation)

        let toAnchorMatrix = getTranslationMatrix(.init(-anchorOffset, 0))
        let fromAnchorMatrix = getTranslationMatrix(.init(anchorOffset, 0))
        let toTargetMatrix = getTranslationMatrix(.init(targetPosition, 0))

        let transformMatrices = [
            baseScaleMatrix,
            fromAnchorMatrix,
            userScaleMatrix,
            rotationMatrix,
            toAnchorMatrix,
            toTargetMatrix,
        ]

        return combineMatrices(transformMatrices)
    }

    private static func getViewTransform() -> float4x4 {
        matrix_identity_float4x4 // camera only looking forward
    }

    private static func getProjectionTransform(canvasSize: SIMD2<Float>) -> float4x4 {
        let halfWidth = canvasSize.x / 2.0
        let halfHeight = canvasSize.y / 2.0
        return orthographicProjection(
            left: -halfWidth,
            right: halfWidth,
            bottom: -halfHeight,
            top: halfHeight,
            near: 0,
            far: 1,
        )
    }

    private static func combineMatrices(_ matrices: [float4x4]) -> float4x4 {
        var resultMatrix = matrix_identity_float4x4
        for transformMatrix in matrices.reversed() {
            resultMatrix *= transformMatrix
        }
        return resultMatrix
    }
}

extension TransformCalculator {

    private static func orthographicProjection(
        left: Float,
        right: Float,
        bottom: Float,
        top: Float,
        near: Float,
        far: Float,
    ) -> float4x4 {
        let sx = 2 / (right - left)
        let sy = 2 / (top - bottom)
        let sz = 1 / (far - near) // Metal z in [0, 1]
        let tx = -(right + left) / (right - left)
        let ty = -(top + bottom) / (top - bottom)
        let tz = -near / (far - near)

        return simd_float4x4(
            SIMD4<Float>(sx, 0, 0, 0),
            SIMD4<Float>(0, sy, 0, 0),
            SIMD4<Float>(0, 0, sz, 0),
            SIMD4<Float>(tx, ty, tz, 1),
        )
    }

    private static func getRotationMatrixX(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(1, 0, 0, 0),
            .init(0, c, s, 0),
            .init(0, -s, c, 0),
            .init(0, 0, 0, 1),
        )
    }

    private static func getRotationMatrixY(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(c, 0, -s, 0),
            .init(0, 1, 0, 0),
            .init(s, 0, c, 0),
            .init(0, 0, 0, 1),
        )
    }

    private static func getRotationMatrixZ(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(c, s, 0, 0),
            .init(-s, c, 0, 0),
            .init(0, 0, 1, 0),
            .init(0, 0, 0, 1),
        )
    }

    private static func getAspectScale(
        canvasSize: SIMD2<Float>,
        textureSize: SIMD2<Float>,
        aspectMode: ImageAspectMode,
    ) -> Float {
        let scaleToCanvas = canvasSize / textureSize
        switch aspectMode {
        case .scaleAspectFit:
            return min(scaleToCanvas.x, scaleToCanvas.y)
        case .scaleAspectFill:
            return max(scaleToCanvas.x, scaleToCanvas.y)
        }
    }

    private static func getScaleMatrix(_ scale: SIMD2<Float>) -> float4x4 {
        .init(
            .init(scale.x, 0, 0, 0),
            .init(0, scale.y, 0, 0),
            .init(0, 0, 1, 0),
            .init(0, 0, 0, 1),
        )
    }

    private static func getTranslationMatrix(_ translation: SIMD3<Float>) -> float4x4 {
        .init(
            .init(1, 0, 0, 0),
            .init(0, 1, 0, 0),
            .init(0, 0, 1, 0),
            .init(translation.x, translation.y, translation.z, 1),
        )
    }
}
