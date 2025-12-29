import Metal
import simd

final class RenderPassSimple {

    private let gpu: GPU
    private let imageRenderPSO: MTLRenderPipelineState

    init(
        gpu: GPU,
        pixelFormat: MTLPixelFormat
    ) throws {
        self.gpu = gpu
        let bundle = Bundle(for: RenderPassSimple.self)
        let library = try gpu.device.makeDefaultLibrary(bundle: bundle)
        let imagePSO = try PipelineStateObjects.simpleImagePipeline(
            library: library,
            pixelFormat: pixelFormat
        )
        self.imageRenderPSO = imagePSO
    }
}

extension RenderPassSimple: RenderPass {
    func resize(size: CGSize) {

    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        descriptor: MTLRenderPassDescriptor,
        input: RenderPassInput
    ) {
        guard
            let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        drawImage(renderEncoder: renderEncoder, input: input)
        
        renderEncoder.endEncoding()
    }

    private func drawImage(
        renderEncoder: MTLRenderCommandEncoder,
        input: RenderPassInput
    ) {
        renderEncoder.label = "Draw Image (Simple)"
        renderEncoder.setRenderPipelineState(imageRenderPSO)

        var transform = input.transform
        renderEncoder.setVertexBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0
        )
        renderEncoder.setFragmentTexture(input.texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}
