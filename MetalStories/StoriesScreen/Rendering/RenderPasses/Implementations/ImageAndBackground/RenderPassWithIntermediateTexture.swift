import Metal
import simd

// MARK: - RenderPassWithRegularIntermediateTexture

final class RenderPassWithRegularIntermediateTexture {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        drawablesPixelFormat: MTLPixelFormat,
        availableFilterCount: Int16,
    ) throws {
        self.device = device
        self.intermediateTexturePixelFormat = .bgra8Unorm
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
        postProcessingPSO = try PipelineStateObjectsFactory.postProcessingBasePipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            filtersCount: availableFilterCount,
        )
    }

    // MARK: Private

    private let device: MTLDevice
    private let intermediateTexturePixelFormat: MTLPixelFormat

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState
    private let postProcessingPSO: MTLRenderPipelineState

    private var intermediateTexture: MTLTexture?

    private func updateIntermediateTexture(forSize size: CGSize) {
        do {
            self.intermediateTexture = try TextureHelper.getTexture(
                device: device,
                pixelFormat: intermediateTexturePixelFormat,
                width: Int(size.width),
                height: Int(size.height),
                storageMode: .private,
                usage: [.shaderRead, .renderTarget]
            )
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }

}

// MARK: RenderPass

extension RenderPassWithRegularIntermediateTexture: RenderPass {

    func resize(size: CGSize) {
        updateIntermediateTexture(forSize: size)
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        input: RenderPassInput,
    ) {
        guard let intermediateTexture else {
            assertionFailure()
            return
        }

        let intermediatePassDescriptor = MTLRenderPassDescriptor()
        intermediatePassDescriptor.colorAttachments[0]?.texture = intermediateTexture
        intermediatePassDescriptor.colorAttachments[0]?.loadAction = .dontCare
        intermediatePassDescriptor.colorAttachments[0]?.storeAction = .store

        let intermediateRenderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: intermediatePassDescriptor
        )
        guard let intermediateRenderEncoder else { return }

        RenderPassHelper.drawBackground(
            renderEncoder: intermediateRenderEncoder,
            backgroundPSO: backgroundPSO,
            label: "Draw Background (intermediate texture)",
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor,
        )

        RenderPassHelper.drawImage(
            renderEncoder: intermediateRenderEncoder,
            imageRenderPSO: imageRenderPSO,
            label: "Draw Image (intermediate texture)",
            texture: input.imageTexture,
            transform: input.mvpTransform,
        )

        intermediateRenderEncoder.endEncoding()

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        )
        guard let renderEncoder else { return }

        // TODO: write better comment and format comment better
        // Flip vertically to compensate for the render-to-texture Y orientation when sampling the intermediate texture.
        RenderPassHelper.drawPostProcessing(
            renderEncoder: renderEncoder,
            postProcessingPSO: postProcessingPSO,
            label: "Post Processing (intermediate texture)",
            texture: intermediateTexture,
            transform: TransformCalculator.getFlippedVerticallyTransform(),
            offset: input.filterPositionOffset,
        )

        renderEncoder.endEncoding()
    }
}
