import Metal

enum RenderPassType {
    case simple
}

enum RenderPassFactory {
    static func getRenderPass(
        gpu: GPU,
        pixelFormat: MTLPixelFormat,
        forRenderPassType renderPassType: RenderPassType
    ) throws -> any RenderPass {
        switch renderPassType {
        case .simple:
            return try RenderPassSimple(gpu: gpu, pixelFormat: pixelFormat)
        }
    }
}
