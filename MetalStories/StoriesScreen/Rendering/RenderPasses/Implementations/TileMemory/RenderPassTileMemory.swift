import Metal
import simd

// MARK: - RenderPassTileMemory

final class RenderPassTileMemory {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        drawablesPixelFormat: MTLPixelFormat,
        availableFilterCount: Int16,
    ) throws {
        self.device = device

        let memorylessTexturePixelFormat = MTLPixelFormat.bgra8Unorm

        let bundle = Bundle(for: Self.self)
        let library = try device.makeDefaultLibrary(bundle: bundle)

        imageRenderPSO = try PipelineStateObjectsFactory.imageTileMemoryPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            memorylessTexturePixelFormat: memorylessTexturePixelFormat,
        )
        backgroundPSO = try PipelineStateObjectsFactory.backgroundTileMemoryPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            memorylessTexturePixelFormat: memorylessTexturePixelFormat,
        )
        postProcessingPSO = try PipelineStateObjectsFactory.postProcessingTileMemoryPipeline(
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            memorylessTexturePixelFormat: memorylessTexturePixelFormat,
            filtersCount: availableFilterCount,
        )

        self.memorylessTexturePixelFormat = memorylessTexturePixelFormat
    }

    // MARK: Internal

    enum RenderPassTileMemoryError: LocalizedError {
        case failedToCreateStencilState
    }

    // MARK: Private

    private let device: MTLDevice

    private let memorylessTexturePixelFormat: MTLPixelFormat

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState
    private let postProcessingPSO: MTLRenderPipelineState

    private var intermediateTexture: MTLTexture?

    private func updateIntermediateTexture(forSize size: CGSize) throws {
        let width = Int(size.width)
        let height = Int(size.height)

        intermediateTexture = try Self.makeTexture(
            device: device,
            pixelFormat: memorylessTexturePixelFormat,
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
            assertionFailure(error.localizedDescription)
        }
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor: MTLRenderPassDescriptor,
        input: RenderPassInput,
    ) {
        guard let intermediateTexture else { return }

        renderPassDescriptor.colorAttachments[1]?.texture = intermediateTexture
        renderPassDescriptor.colorAttachments[1]?.loadAction = .dontCare
        renderPassDescriptor.colorAttachments[1]?.storeAction = .dontCare

        let renderEncoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPassDescriptor
        )
        guard let renderEncoder else { return }

        RenderPassHelper.drawBackground(
            renderEncoder: renderEncoder,
            backgroundPSO: backgroundPSO,
            label: "Draw Background (Tile Memory)",
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor,
        )
        RenderPassHelper.drawImage(
            renderEncoder: renderEncoder,
            imageRenderPSO: imageRenderPSO,
            label: "Draw Image (Tile Memory)",
            texture: input.imageTexture,
            transform: input.mvpTransform,
        )
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

    private static func makeTexture(
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

extension RenderPassTileMemory.RenderPassTileMemoryError {

    var errorDescription: String? {
        switch self {
        case .failedToCreateStencilState:
            "Unable to create stencil state."
        }
    }
}
