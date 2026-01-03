import Metal
import simd

// MARK: - RenderPassTileMemory

final class RenderPassTileMemory {

    // MARK: Lifecycle

    init(
        gpu: GPU,
        pixelFormat: MTLPixelFormat,
    ) throws {
        self.gpu = gpu
        self.pixelFormat = pixelFormat
        intermediateTexturePixelFormat = pixelFormat
        depthTexturePixelFormat = .depth32Float
        let bundle = Bundle(for: RenderPassSimple.self)
        let library = try gpu.device.makeDefaultLibrary(bundle: bundle)
        imageRenderPSO = try PipelineStateObjectsTileMemory.imagePipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsTileMemory.backgroundPipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat,
        )
        postProcessingPSO = try PipelineStateObjectsTileMemory.postProcessingPipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat,
        )

        depthStencilState = try Self.makeDepthStencilState(device: gpu.device)
        postProcessingDepthStencilState = try Self.makePostProcessingDepthStencilState(device: gpu.device)
    }

    // MARK: Private

    private let gpu: GPU
    private let pixelFormat: MTLPixelFormat
    private let intermediateTexturePixelFormat: MTLPixelFormat
    private let depthTexturePixelFormat: MTLPixelFormat

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState
    private let postProcessingPSO: MTLRenderPipelineState

    private let depthStencilState: MTLDepthStencilState
    private let postProcessingDepthStencilState: MTLDepthStencilState

    private var intermediateTexture: MTLTexture?
    private var depthTexture: MTLTexture?

    private static func makeDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less // TODO: double check
        descriptor.isDepthWriteEnabled = true
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw NSError() // TODO: throw normal error
        }
        return stencilState
    }

    // TODO: do we really need it?
    private static func makePostProcessingDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.isDepthWriteEnabled = false
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw NSError() // TODO: throw normal error
        }
        return stencilState
    }

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
        descriptor.storageMode = .memoryless
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
        let depthTexture = Self.makeTexture(
            device: gpu.device,
            pixelFormat: .depth32Float,
            width: Int(size.width),
            height: Int(size.height),
        )
        guard let texture, let depthTexture else {
            assertionFailure()
            return
        }
        intermediateTexture = texture
        self.depthTexture = depthTexture
    }

}

// MARK: RenderPass

extension RenderPassTileMemory: RenderPass {

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
        guard let intermediateTexture, let depthTexture else {
            assertionFailure()
            return
        }

        rpd.colorAttachments[1]?.texture = intermediateTexture
        rpd.colorAttachments[1]?.loadAction = .dontCare
        rpd.colorAttachments[1]?.storeAction = .dontCare

        rpd.depthAttachment.texture = depthTexture
        rpd.depthAttachment.storeAction = .dontCare

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else {
            return
        }

        renderEncoder.setDepthStencilState(depthStencilState)

        // pay attention to the order of image-background

        RenderPassHelper.drawImage(
            renderEncoder: renderEncoder,
            imageRenderPSO: imageRenderPSO,
            label: "Draw Image (Tile Memory)",
            texture: input.imageTexture,
            transform: input.transform
        )
        
        RenderPassHelper.drawBackground(
            renderEncoder: renderEncoder,
            backgroundPSO: backgroundPSO,
            label: "Draw Background (Tile Memory)",
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor
        )

        renderEncoder.setDepthStencilState(postProcessingDepthStencilState)
        
        // pay attention on transform
        RenderPassHelper.drawPostProcessing(
            renderEncoder: renderEncoder,
            postProcessingPSO: postProcessingPSO,
            label: "Post Processing (Tile Memory)",
            texture: nil,
            transform: TransformCalculator.getIdentityTransform(),
            offset: input.filterPositionOffset
        )

        renderEncoder.endEncoding()
    }
}
