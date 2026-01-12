import Metal
import simd

enum RenderPassHelper {
    static func drawImage(
        renderEncoder: MTLRenderCommandEncoder,
        imageRenderPSO: MTLRenderPipelineState,
        label: String,
        texture: MTLTexture,
        transform: float4x4,
    ) {
        renderEncoder.label = label
        renderEncoder.setRenderPipelineState(imageRenderPSO)

        var transform = transform
        renderEncoder.setVertexBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0,
        )
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    static func drawBackground(
        renderEncoder: MTLRenderCommandEncoder,
        backgroundPSO: MTLRenderPipelineState,
        label: String,
        topColor: SIMD4<Float>,
        bottomColor: SIMD4<Float>,
    ) {
        renderEncoder.label = label
        renderEncoder.setRenderPipelineState(backgroundPSO)

        // TODO: check, if translation needed here
        var transform = TransformCalculator.getIdentityTransform()
        renderEncoder.setVertexBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0,
        )
        var topColor = topColor
        renderEncoder.setFragmentBytes(
            &topColor,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 0,
        )
        var bottomColor = bottomColor
        renderEncoder.setFragmentBytes(
            &bottomColor,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 1,
        )
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    static func drawPostProcessing(
        renderEncoder: MTLRenderCommandEncoder,
        postProcessingPSO: MTLRenderPipelineState,
        label: String,
        texture: MTLTexture?,
        transform: float4x4?,
        offset: Float,
    ) {
        renderEncoder.label = label
        renderEncoder.setRenderPipelineState(postProcessingPSO)

        if var transform = transform {
            renderEncoder.setVertexBytes(
                &transform,
                length: MemoryLayout<float4x4>.stride,
                index: 0,
            )
        }

        var offset = offset
        renderEncoder.setFragmentBytes(
            &offset,
            length: MemoryLayout<Float>.stride,
            index: 0,
        )

        if let texture {
            renderEncoder.setFragmentTexture(texture, index: 0)
        }

        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}
