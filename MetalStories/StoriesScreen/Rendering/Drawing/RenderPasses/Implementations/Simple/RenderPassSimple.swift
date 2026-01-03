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

        RenderPassHelper.drawBackground(
            renderEncoder: renderEncoder,
            backgroundPSO: backgroundPSO,
            label: "Draw Background (Simple)",
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor
        )

        RenderPassHelper.drawImage(
            renderEncoder: renderEncoder,
            imageRenderPSO: imageRenderPSO,
            label: "Draw Image (Simple)",
            texture: input.imageTexture,
            transform: input.transform
        )

        renderEncoder.endEncoding()
    }
}
