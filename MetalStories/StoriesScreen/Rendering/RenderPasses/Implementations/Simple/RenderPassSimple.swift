import Metal
import simd

// MARK: - RenderPassSimple

final class RenderPassSimple {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
    ) throws {
        self.pixelFormat = pixelFormat
        let bundle = Bundle(for: RenderPassSimple.self)
        let library = try device.makeDefaultLibrary(bundle: bundle)
        imageRenderPSO = try PipelineStateObjectsFactory.imageBasePipeline(
            library: library,
            pixelFormat: pixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsFactory.backgroundBasePipeline(
            library: library,
            pixelFormat: pixelFormat,
        )
    }

    // MARK: Private

    private let pixelFormat: MTLPixelFormat

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
