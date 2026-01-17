import Metal
import simd

// MARK: - RenderPassDirectWithDepthError

enum RenderPassDirectWithDepthError: LocalizedError {
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

// MARK: - RenderPassDirectWithDepth

final class RenderPassDirectWithDepth {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        drawablesPixelFormat: MTLPixelFormat,
        availableFilterCount: Int16,
    ) throws {
        self.device = device

        let depthTexturePixelFormat = MTLPixelFormat.depth16Unorm

        let bundle = Bundle(for: Self.self)
        let library = try device.makeDefaultLibrary(bundle: bundle)

        imageRenderPSO = try PipelineStateObjectsFactory.imageDirectPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            depthAttachmentPixelFormat: depthTexturePixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsFactory.backgroundDirectPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            depthAttachmentPixelFormat: depthTexturePixelFormat,
        )
        postProcessingPSO = try PipelineStateObjectsFactory.postProcessingDirectPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            depthAttachmentPixelFormat: depthTexturePixelFormat,
            filtersCount: availableFilterCount,
        )

        depthStencilState = try Self.makeDepthStencilState(device: device)
        postProcessingDepthStencilState = try Self.makePostProcessingDepthStencilState(device: device)

        self.depthTexturePixelFormat = depthTexturePixelFormat
    }

    // MARK: Private

    private let device: MTLDevice

    private let depthTexturePixelFormat: MTLPixelFormat

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState
    private let postProcessingPSO: MTLRenderPipelineState

    private let depthStencilState: MTLDepthStencilState
    private let postProcessingDepthStencilState: MTLDepthStencilState

    private var depthTexture: MTLTexture?

    private func updateDepthTexture(forSize size: CGSize) throws {
        let width = Int(size.width)
        let height = Int(size.height)

        depthTexture = try Self.makeDepthTexture(
            device: device,
            pixelFormat: depthTexturePixelFormat,
            width: width,
            height: height,
        )
    }
}

// MARK: RenderPass

extension RenderPassDirectWithDepth: RenderPass {

    func resize(size: CGSize) {
        do {
            try updateDepthTexture(forSize: size)
        } catch {
            depthTexture = nil
            assertionFailure(error.localizedDescription)
        }
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        input: RenderPassInput,
    ) {
        renderPassDescriptor.colorAttachments[0]?.loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0]?.storeAction = .store

        if let depthTexture {
            renderPassDescriptor.depthAttachment.texture = depthTexture
            renderPassDescriptor.depthAttachment.loadAction = .clear
            renderPassDescriptor.depthAttachment.clearDepth = 1.0
            renderPassDescriptor.depthAttachment.storeAction = .dontCare
        }

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        )
        guard let renderEncoder else { return }

        renderEncoder.setDepthStencilState(depthStencilState)

        RenderPassHelper.drawImage(
            renderEncoder: renderEncoder,
            imageRenderPSO: imageRenderPSO,
            label: "Draw Image (Direct With Depth)",
            texture: input.imageTexture,
            transform: input.mvpTransform,
        )

        RenderPassHelper.drawBackground(
            renderEncoder: renderEncoder,
            backgroundPSO: backgroundPSO,
            label: "Draw Background (Direct With Depth)",
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor,
        )

        renderEncoder.setDepthStencilState(postProcessingDepthStencilState)

        RenderPassHelper.drawPostProcessing(
            renderEncoder: renderEncoder,
            postProcessingPSO: postProcessingPSO,
            label: "Post Processing (Direct With Depth)",
            texture: nil,
            transform: TransformCalculator.getIdentityTransform(),
            offset: input.filterPositionOffset,
        )

        renderEncoder.endEncoding()
    }
}

// MARK: helpers

extension RenderPassDirectWithDepth {
    private static func makeDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = true
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw RenderPassDirectWithDepthError.failedToCreateStencilState
        }
        return stencilState
    }

    private static func makePostProcessingDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .always
        descriptor.isDepthWriteEnabled = false
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw RenderPassDirectWithDepthError.failedToCreateStencilState
        }
        return stencilState
    }

    private static func makeDepthTexture(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
    ) throws -> MTLTexture {
        try TextureHelper.getTexture(
            device: device,
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            storageMode: .memoryless,
            usage: [.renderTarget],
        )
    }
}
