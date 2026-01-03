import Metal
import simd

// MARK: - RenderPassSimple

final class RenderPassSimple {

    // MARK: Lifecycle

    init(
        gpu: GPU,
        pixelFormat: MTLPixelFormat,
    ) throws {
        self.gpu = gpu
        self.pixelFormat = pixelFormat
        let bundle = Bundle(for: RenderPassSimple.self)
        let library = try gpu.device.makeDefaultLibrary(bundle: bundle)
        imageRenderPSO = try PipelineStateObjectsSimple.imagePipeline(
            library: library,
            pixelFormat: pixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsSimple.backgroundPipeline(
            library: library,
            pixelFormat: pixelFormat,
        )
    }

    // MARK: Private

    private let gpu: GPU
    private let pixelFormat: MTLPixelFormat

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState

}

// MARK: RenderPass

extension RenderPassSimple: RenderPass {

    // MARK: Internal

    func copy() throws -> any RenderPass {
        try RenderPassSimple(gpu: gpu, pixelFormat: pixelFormat)
    }

    func resize(size _: CGSize) {
        // --
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor rpd: MTLRenderPassDescriptor,
        input: RenderPassInput,
    ) {
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd)
        else {
            return
        }

        drawBackground(
            renderEncoder: renderEncoder,
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor,
        )
        drawImage(
            renderEncoder: renderEncoder,
            texture: input.imageTexture,
            transform: input.transform,
        )

        renderEncoder.endEncoding()
    }

    // MARK: Private

    private func drawImage(
        renderEncoder: MTLRenderCommandEncoder,
        texture: MTLTexture,
        transform: float4x4,
    ) {
        renderEncoder.label = "Draw Image (Simple)"
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

    private func drawBackground(
        renderEncoder: MTLRenderCommandEncoder,
        topColor: SIMD4<Float>,
        bottomColor: SIMD4<Float>,
    ) {
        renderEncoder.label = "Draw Background (Simple)"
        renderEncoder.setRenderPipelineState(backgroundPSO)

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
}
