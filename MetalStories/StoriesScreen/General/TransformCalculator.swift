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
            aspectMode: aspectMode
        )
        let viewTransform = getViewTransform()
        let projectionTransform = getProjectionTransform(canvasSize: canvasSize)

        return projectionTransform * viewTransform * modelTransform
    }

    static func getFlippedVerticallyTransform() -> float4x4 {
        scaleMatrix(.init(x: 1, y: -1))
    }

    static func getIdentityTransform() -> float4x4 {
        matrix_identity_float4x4
    }
}

private extension TransformCalculator {
    static func getModelTransform(
        textureSize: SIMD2<Float>,
        canvasSize: SIMD2<Float>,
        anchorPoint: SIMD2<Float>,
        anchorToImageOffset: SIMD2<Float>,
        rotation: Float,
        scale: Float,
        aspectMode: ImageAspectMode,
    ) -> float4x4 {

        let aspectScale = aspectScale(
            canvasSize: canvasSize,
            textureSize: textureSize,
            aspectMode: aspectMode,
        )
        let scaledTextureSize = textureSize * aspectScale

        let targetPosition = (anchorPoint + anchorToImageOffset - 0.5) * canvasSize
        let anchorOffset = anchorToImageOffset * canvasSize

        let userScaleMatrix = scaleMatrix(.init(scale, scale))
        let baseScaleMatrix = scaleMatrix(scaledTextureSize / 2.0)
        let rotationMatrix = rotationMatrixZ(rotation)

        let toAnchorMatrix = translationMatrix(-anchorOffset)
        let fromAnchorMatrix = translationMatrix(anchorOffset)
        let toTargetMatrix = translationMatrix(targetPosition)
        
        let transformMatrices = [
            baseScaleMatrix,
            fromAnchorMatrix,
            userScaleMatrix,
            rotationMatrix,
            toAnchorMatrix,
            toTargetMatrix,
        ]

        var resultMatrix = matrix_identity_float4x4
        for transformMatrix in transformMatrices.reversed() {
            resultMatrix *= transformMatrix
        }
        return resultMatrix
    }

    static func getViewTransform() -> float4x4 {
        matrix_identity_float4x4 // camera only looking forward
    }

    static func getProjectionTransform(canvasSize: SIMD2<Float>) -> float4x4 {
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

    static func targetAspectMode(
        for aspectModeType: ImageAspectModeType,
        textureSize: SIMD2<Float>,
    ) -> ImageAspectMode {
        let textureAspect = textureSize.x / textureSize.y
        switch aspectModeType {
        case .automatic(let threshold):
            return textureAspect < threshold ? .scaleAspectFill : .scaleAspectFit
        case .specific(let aspectMode):
            return aspectMode
        }
    }
}

private extension TransformCalculator {

    // MARK: projection

    static func orthographicProjection(
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

    // MARK: rotation

    static func rotationMatrixX(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(1, 0, 0, 0),
            .init(0, c, s, 0),
            .init(0, -s, c, 0),
            .init(0, 0, 0, 1),
        )
    }

    static func rotationMatrixY(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(c, 0, -s, 0),
            .init(0, 1, 0, 0),
            .init(s, 0, c, 0),
            .init(0, 0, 0, 1),
        )
    }

    static func rotationMatrixZ(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(c, s, 0, 0),
            .init(-s, c, 0, 0),
            .init(0, 0, 1, 0),
            .init(0, 0, 0, 1),
        )
    }

    // MARK: scale

    static func aspectScale(
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

    static func scaleMatrix(_ scale: SIMD2<Float>) -> float4x4 {
        .init(
            .init(scale.x, 0, 0, 0),
            .init(0, scale.y, 0, 0),
            .init(0, 0, 1, 0),
            .init(0, 0, 0, 1),
        )
    }

    // MARK: translation

    static func translationMatrix(_ translation: SIMD2<Float>) -> float4x4 {
        .init(
            .init(1, 0, 0, 0),
            .init(0, 1, 0, 0),
            .init(0, 0, 1, 0),
            .init(translation.x, translation.y, 0, 1),
        )
    }
}
