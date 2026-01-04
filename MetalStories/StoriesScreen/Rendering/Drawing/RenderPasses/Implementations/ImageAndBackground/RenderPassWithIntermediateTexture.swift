import Metal
import simd

// MARK: - RenderPassWithRegularIntermediateTexture

final class RenderPassWithRegularIntermediateTexture {

    // MARK: Lifecycle

    init(
        gpu: GPU,
        pixelFormat: MTLPixelFormat,
    ) throws {
        self.gpu = gpu
        self.pixelFormat = pixelFormat
        let bundle = Bundle(for: RenderPassSimple.self)
        let library = try gpu.device.makeDefaultLibrary(bundle: bundle)
        imageRenderPSO = try PipelineStateObjectsFactory.imageBasePipeline(
            library: library,
            pixelFormat: pixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsFactory.backgroundBasePipeline(
            library: library,
            pixelFormat: pixelFormat,
        )
        postProcessingPSO = try PipelineStateObjectsFactory.postProcessingBasePipeline(
            library: library,
            pixelFormat: pixelFormat,
        )
    }

    // MARK: Private

    private let gpu: GPU
    private let pixelFormat: MTLPixelFormat

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState
    private let postProcessingPSO: MTLRenderPipelineState

    private var intermediateTexture: MTLTexture?

    private static func makeTexture(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false,
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }

    private func updateIntermediateTexture(forSize size: CGSize) {
        let texture = Self.makeTexture(
            device: gpu.device,
            pixelFormat: pixelFormat,
            width: Int(size.width),
            height: Int(size.height),
        )
        guard let texture else {
            assertionFailure()
            return
        }
        intermediateTexture = texture
    }

}

// MARK: RenderPass

extension RenderPassWithRegularIntermediateTexture: RenderPass {

    // MARK: Internal

    func copy() throws -> any RenderPass {
        try Self(gpu: gpu, pixelFormat: pixelFormat)
    }

    func resize(size: CGSize) {
        updateIntermediateTexture(forSize: size)
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor rpd: MTLRenderPassDescriptor,
        input: RenderPassInput,
    ) {
        guard let intermediateTexture else {
            assertionFailure()
            return
        }

        let intermediatePassDescriptor = MTLRenderPassDescriptor()
        let intermediateAttachment = intermediatePassDescriptor.colorAttachments[0]
        intermediateAttachment?.texture = intermediateTexture
        intermediateAttachment?.loadAction = .dontCare
        intermediateAttachment?.storeAction = .store

        guard let intermediateRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: intermediatePassDescriptor)
        else {
            return
        }

        RenderPassHelper.drawBackground(
            renderEncoder: intermediateRenderEncoder,
            backgroundPSO: backgroundPSO,
            label: "Draw Background (intermediate texture)",
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor
        )

        RenderPassHelper.drawImage(
            renderEncoder: intermediateRenderEncoder,
            imageRenderPSO: imageRenderPSO,
            label: "Draw Image (intermediate texture)",
            texture: input.imageTexture,
            transform: input.transform
        )

        intermediateRenderEncoder.endEncoding()

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else {
            return
        }

        // pay attention on transform
        RenderPassHelper.drawPostProcessing(
            renderEncoder: renderEncoder,
            postProcessingPSO: postProcessingPSO,
            label: "Post Processing (intermediate texture)",
            texture: intermediateTexture,
            transform: TransformCalculator.getFlippedVerticallyTransform(),
            offset: input.filterPositionOffset
        )

        renderEncoder.endEncoding()
    }
}
