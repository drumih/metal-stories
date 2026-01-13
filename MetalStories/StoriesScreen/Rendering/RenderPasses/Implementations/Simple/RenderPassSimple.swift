import Metal
import simd

// MARK: - RenderPassSimple

final class RenderPassSimple {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        drawablesPixelFormat: MTLPixelFormat,
    ) throws {
        let bundle = Bundle(for: RenderPassSimple.self)
        let library = try device.makeDefaultLibrary(bundle: bundle)
        imageRenderPSO = try PipelineStateObjectsFactory.imageBasePipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsFactory.backgroundBasePipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
    }

    // MARK: Private

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState

}

// MARK: RenderPass

extension RenderPassSimple: RenderPass {

    func resize(size _: CGSize) {
        // --
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        input: RenderPassInput,
    ) {
        let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        )
        guard let renderEncoder else { return }

        RenderPassHelper.drawBackground(
            renderEncoder: renderEncoder,
            backgroundPSO: backgroundPSO,
            label: "Draw Background (Simple)",
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor,
        )

        RenderPassHelper.drawImage(
            renderEncoder: renderEncoder,
            imageRenderPSO: imageRenderPSO,
            label: "Draw Image (Simple)",
            texture: input.imageTexture,
            transform: input.mvpTransform,
        )

        renderEncoder.endEncoding()
    }
}
