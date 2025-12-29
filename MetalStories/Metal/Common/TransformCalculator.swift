import simd

enum TransformCalculator {
    static func getTransform(
        textureSize: SIMD2<Float>,
        canvasSize: SIMD2<Float>,
        anchor: SIMD2<Float>,
        scale: Float,
        rotation: Float,
        translation: SIMD2<Float>,
        flipVertically: Bool, // remove later?
        mirror: Bool, // remove later?
        aspectMode: ImageAspectMode
    ) -> float4x4 {
        let modelTransform = getModelTransform(
            textureSize: textureSize,
            canvasSize: canvasSize,
            anchor: anchor,
            scale: scale,
            rotation: rotation,
            translation: translation,
            flipVertically: flipVertically,
            mirror: mirror,
            aspectMode: aspectMode
        )
        let viewTransform = getViewTransform()
        let projectionTransform = getProjectionTransform(canvasSize: canvasSize)
        
        return projectionTransform * viewTransform * modelTransform
    }
}

private extension TransformCalculator {
    static func getModelTransform(
        textureSize: SIMD2<Float>,
        canvasSize: SIMD2<Float>,
        anchor: SIMD2<Float>,
        scale: Float,
        rotation: Float,
        translation: SIMD2<Float>,
        flipVertically: Bool,
        mirror: Bool,
        aspectMode: ImageAspectMode
    ) -> float4x4 {
        let textureAspect = textureSize.x / textureSize.y
        let resolvedAspectMode: ImageAspectMode
        switch aspectMode {
        case .automatic(let threshold):
            resolvedAspectMode = textureAspect < threshold ? .scaleAspectFill : .scaleAspectFit
        default:
            resolvedAspectMode = aspectMode
        }

        let scaleToCanvasX = canvasSize.x / textureSize.x
        let scaleToCanvasY = canvasSize.y / textureSize.y
        let aspectScale: Float
        switch resolvedAspectMode {
        case .scaleAspectFit:
            aspectScale = min(scaleToCanvasX, scaleToCanvasY)
        case .scaleAspectFill:
            aspectScale = max(scaleToCanvasX, scaleToCanvasY)
        case .automatic:
            aspectScale = min(scaleToCanvasX, scaleToCanvasY)
        }

        let scaledTextureSize = textureSize * aspectScale
        let anchorOffset = (anchor - 0.5) * scaledTextureSize
        let targetPosition = (translation - 0.5) * canvasSize

        let flipY: Float = flipVertically ? -1 : 1
        let flipX: Float = mirror ? -1 : 1
        let userScaleMatrix = scaleMatrix(.init(scale * flipX, scale * flipY))
        let baseScaleMatrix = scaleMatrix(scaledTextureSize / 2.0)
        let rotationMatrix = rotationMatrixZ(rotation)

        let toAnchor = translationMatrix(anchorOffset)
        let fromAnchor = translationMatrix(-anchorOffset)
        let toTarget = translationMatrix(targetPosition - anchorOffset)

        return toTarget * toAnchor * rotationMatrix * userScaleMatrix * fromAnchor * baseScaleMatrix
    }
    
    static func getViewTransform() -> float4x4 {
        matrix_identity_float4x4 // no camera movement
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
            far: 1
        )
    }
}

private extension TransformCalculator {
    
    static func orthographicProjection(
        left: Float,
        right: Float,
        bottom: Float,
        top: Float,
        near: Float,
        far: Float
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
            SIMD4<Float>(tx, ty, tz, 1)
        )
    }

    
    static func rotationMatrixX(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(1, 0, 0, 0),
            .init(0, c, s, 0),
            .init(0, -s, c, 0),
            .init(0, 0, 0, 1)
        )
    }
    
    static func rotationMatrixY(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(c, 0, -s, 0),
            .init(0, 1, 0, 0),
            .init(s, 0, c, 0),
            .init(0, 0, 0, 1)
        )
    }
    
    static func rotationMatrixZ(_ radians: Float) -> float4x4 {
        let s = sin(radians)
        let c = cos(radians)

        return .init(
            .init(c, s, 0, 0),
            .init(-s, c, 0, 0),
            .init(0, 0, 1, 0),
            .init(0, 0, 0, 1)
        )
    }
    
    static func scaleMatrix(_ scale: SIMD2<Float>) -> float4x4 {
        .init(
            .init(scale.x, 0, 0, 0),
            .init(0, scale.y, 0, 0),
            .init(0, 0, 1, 0),
            .init(0, 0, 0, 1)
        )
    }
    
    static func translationMatrix(_ translation: SIMD2<Float>) -> float4x4 {
        .init(
            .init(1, 0, 0, 0),
            .init(0, 1, 0, 0),
            .init(0, 0, 1, 0),
            .init(translation.x, translation.y, 0, 1)
        )
    }
}
