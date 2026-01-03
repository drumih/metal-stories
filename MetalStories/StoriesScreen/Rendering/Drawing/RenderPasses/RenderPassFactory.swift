import Metal

// MARK: - RenderPassType

enum RenderPassType: Int {
    case simple
    case withIntermediateTexture
    case tileMemory
}

// MARK: - RenderPassFactory

enum RenderPassFactory {
    static func getRenderPass(
        gpu: GPU,
        pixelFormat: MTLPixelFormat,
        forRenderPassType renderPassType: RenderPassType,
    ) throws -> any RenderPass {
        switch renderPassType {
        case .simple:
            try RenderPassSimple(
                gpu: gpu,
                pixelFormat: pixelFormat,
            )

        case .withIntermediateTexture:
            try RenderPassWithRegularIntermediateTexture(
                gpu: gpu,
                pixelFormat: pixelFormat,
            )

        case .tileMemory:
            try RenderPassTileMemory(
                gpu: gpu,
                pixelFormat: pixelFormat,
            )
        }
    }
}
