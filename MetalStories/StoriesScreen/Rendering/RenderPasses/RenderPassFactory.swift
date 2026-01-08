import Metal

// MARK: - RenderPassType

enum RenderPassType: Int {
    case simple
    case withIntermediateTexture
    case tileMemory
}

// MARK: - RenderPassFactory

final class RenderPassFactory {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        renderPassType: RenderPassType,
    ) {
        self.device = device
        self.pixelFormat = pixelFormat
        self.renderPassType = renderPassType
    }

    // MARK: Internal

    func createNewRenderPass() throws -> any RenderPass {
        switch renderPassType {
        case .simple:
            try RenderPassSimple(
                device: device,
                pixelFormat: pixelFormat,
            )

        case .withIntermediateTexture:
            try RenderPassWithRegularIntermediateTexture(
                device: device,
                pixelFormat: pixelFormat,
            )

        case .tileMemory:
            try RenderPassTileMemory(
                device: device,
                pixelFormat: pixelFormat,
            )
        }
    }

    // MARK: Private

    private let device: MTLDevice

    private let pixelFormat: MTLPixelFormat
    private let renderPassType: RenderPassType

}
