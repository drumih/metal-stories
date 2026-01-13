import Metal
import simd

// MARK: - RenderPassTileMemoryError

enum RenderPassTileMemoryError: LocalizedError {
    case failedToCreateTexture
    case failedToCreateStencilState

    var errorDescription: String? {
        switch self {
        case .failedToCreateTexture:
            "Unable to create texture."
        case .failedToCreateStencilState:
            "Unable to create stencil state."
        }
    }
}

// MARK: - RenderPassTileMemory

final class RenderPassTileMemory {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        drawablesPixelFormat: MTLPixelFormat,
    ) throws {
        self.device = device

        let memorylessTexturePixelFormat: MTLPixelFormat = .bgra8Unorm
        let depthTexturePixelFormat: MTLPixelFormat = .depth32Float

        let bundle = Bundle(for: Self.self)
        let library = try device.makeDefaultLibrary(bundle: bundle)

        imageRenderPSO = try PipelineStateObjectsFactory.imageTileMemoryPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            memorylessTexturePixelFormat: memorylessTexturePixelFormat,
            depthAttachmentPixelFormat: depthTexturePixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsFactory.backgroundTileMemoryPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            memorylessTexturePixelFormat: memorylessTexturePixelFormat,
            depthAttachmentPixelFormat: depthTexturePixelFormat,
        )
        postProcessingPSO = try PipelineStateObjectsFactory.postProcessingTileMemoryPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            memorylessTexturePixelFormat: memorylessTexturePixelFormat,
            depthAttachmentPixelFormat: depthTexturePixelFormat,
        )

        depthStencilState = try Self.makeDepthStencilState(device: device)
        postProcessingDepthStencilState = try Self.makePostProcessingDepthStencilState(device: device)

        self.memorylessTexturePixelFormat = memorylessTexturePixelFormat
        self.depthTexturePixelFormat = depthTexturePixelFormat
    }

    // MARK: Private

    private let device: MTLDevice

    private let memorylessTexturePixelFormat: MTLPixelFormat
    private let depthTexturePixelFormat: MTLPixelFormat

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState
    private let postProcessingPSO: MTLRenderPipelineState

    private let depthStencilState: MTLDepthStencilState // TODO: should we ignore depth for simplicity?
    private let postProcessingDepthStencilState: MTLDepthStencilState

    private var intermediateTexture: MTLTexture?
    private var depthTexture: MTLTexture?

    private func updateIntermediateTexture(forSize size: CGSize) throws {
        let width = Int(size.width)
        let height = Int(size.height)

        self.intermediateTexture = try Self.makeTexture(
            device: device,
            pixelFormat: memorylessTexturePixelFormat,
            width: width,
            height: height,
        )
        self.depthTexture = try Self.makeTexture(
            device: device,
            pixelFormat: depthTexturePixelFormat,
            width: width,
            height: height,
        )
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
            assertionFailure(error.localizedDescription)
        }
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        input: RenderPassInput,
    ) {
        guard let intermediateTexture, let depthTexture else { return }

        renderPassDescriptor.colorAttachments[1]?.texture = intermediateTexture
        renderPassDescriptor.colorAttachments[1]?.loadAction = .dontCare
        renderPassDescriptor.colorAttachments[1]?.storeAction = .dontCare

        renderPassDescriptor.depthAttachment.texture = depthTexture
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .dontCare

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        )
        guard let renderEncoder else { return }

        renderEncoder.setDepthStencilState(depthStencilState)

        // Draw the image first to write depth, then draw the background depth-tested so it stays behind.

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

// MARK: helpers

extension RenderPassTileMemory {
    // TODO: check for depth!!
    private static func makeDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw RenderPassTileMemoryError.failedToCreateStencilState
        }
        return stencilState
    }

    // TODO: do we really need it?
    private static func makePostProcessingDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.isDepthWriteEnabled = false
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw RenderPassTileMemoryError.failedToCreateStencilState
        }
        return stencilState
    }

    private static func makeTexture(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
    ) throws -> MTLTexture {
        guard width > 0, height > 0 else {
            throw RenderPassTileMemoryError.failedToCreateTexture
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false,
        )
        descriptor.storageMode = .memoryless
        descriptor.usage = [.shaderRead, .renderTarget]
        let texture = device.makeTexture(descriptor: descriptor)

        guard let texture else {
            throw RenderPassTileMemoryError.failedToCreateTexture
        }

        return texture
    }
}
