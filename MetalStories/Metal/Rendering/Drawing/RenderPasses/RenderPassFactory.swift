import Metal

enum RenderPassType {
    case simple
    case withIntermediateTexture
    case tiled
}

enum RenderPassFactory {
    static func getRenderPass(
        gpu: GPU,
        pixelFormat: MTLPixelFormat,
        forRenderPassType renderPassType: RenderPassType
    ) throws -> any RenderPass {
        switch renderPassType {
        case .simple:
            try RenderPassSimple(
                gpu: gpu,
                pixelFormat: pixelFormat
            )
        case .withIntermediateTexture:
            try RenderPassWithRegularIntermediateTexture(
                gpu: gpu,
                pixelFormat: pixelFormat
            )
        case .tiled:
            try RenderPassTiled(
                gpu: gpu,
                pixelFormat: pixelFormat
            )
        }
    }
}
