import Metal
import simd

// MARK: - RenderPassTileMemoryError

enum RenderPassTileMemoryError: LocalizedError {
    case failedToCreateTexture
    case failedToCreateStensilState

    var errorDescription: String? {
        switch self {
        case .failedToCreateTexture:
            "Unable to create texture."
        case .failedToCreateStensilState:
            "Unable to create stencil state."
        }
    }
}

// MARK: - RenderPassTileMemory

final class RenderPassTileMemory {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
    ) throws {
        self.device = device
        self.pixelFormat = pixelFormat

        intermediateTexturePixelFormat = pixelFormat
        depthTexturePixelFormat = .depth32Float

        let bundle = Bundle(for: Self.self)
        let library = try device.makeDefaultLibrary(bundle: bundle)
        imageRenderPSO = try PipelineStateObjectsFactory.imageTileMemoryPipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsFactory.backgroundTileMemoryPipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat,
        )
        postProcessingPSO = try PipelineStateObjectsFactory.postProcessingTileMemoryPipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat,
        )

        depthStencilState = try Self.makeDepthStencilState(device: device)
        postProcessingDepthStencilState = try Self.makePostProcessingDepthStencilState(device: device)
    }

    // MARK: Private

    private let device: MTLDevice
    private let pixelFormat: MTLPixelFormat

    // use another pixel format
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
            throw RenderPassTileMemoryError.failedToCreateStensilState
        }
        return stencilState
    }

    // TODO: do we really need it?
    private static func makePostProcessingDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.isDepthWriteEnabled = false
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw RenderPassTileMemoryError.failedToCreateStensilState
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

    private func updateIntermediateTexture(forSize size: CGSize) throws {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0 else {
            throw RenderPassTileMemoryError.failedToCreateTexture
        }
        let texture = Self.makeTexture(
            device: device,
            pixelFormat: pixelFormat,
            width: width,
            height: height,
        )
        let depthTexture = Self.makeTexture(
            device: device,
            pixelFormat: .depth32Float,
            width: width,
            height: height,
        )
        guard let texture else {
            throw RenderPassTileMemoryError.failedToCreateTexture
        }
        guard let depthTexture else {
            throw RenderPassTileMemoryError.failedToCreateTexture
        }
        intermediateTexture = texture
        self.depthTexture = depthTexture
    }

}

// MARK: RenderPass

extension RenderPassTileMemory: RenderPass {

    func resize(size: CGSize) {
        do {
            try updateIntermediateTexture(forSize: size)
        } catch {
            intermediateTexture = nil
            depthTexture = nil
            #if DEBUG
            assertionFailure(error.localizedDescription)
            #endif
        }
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor rpd: MTLRenderPassDescriptor,
        input: RenderPassInput,
    ) {
        guard let intermediateTexture, let depthTexture else { return }

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
            transform: input.mvpTransform,
        )

        RenderPassHelper.drawBackground(
            renderEncoder: renderEncoder,
            backgroundPSO: backgroundPSO,
            label: "Draw Background (Tile Memory)",
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor,
        )

        renderEncoder.setDepthStencilState(postProcessingDepthStencilState)

        // pay attention on transform
        RenderPassHelper.drawPostProcessing(
            renderEncoder: renderEncoder,
            postProcessingPSO: postProcessingPSO,
            label: "Post Processing (Tile Memory)",
            texture: nil,
            transform: TransformCalculator.getIdentityTransform(),
            offset: input.filterPositionOffset,
        )

        renderEncoder.endEncoding()
    }
}
