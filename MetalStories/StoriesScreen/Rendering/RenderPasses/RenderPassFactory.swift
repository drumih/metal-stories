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
        drawablesPixelFormat: MTLPixelFormat,
        renderPassType: RenderPassType,
    ) {
        self.device = device
        self.drawablesPixelFormat = drawablesPixelFormat
        self.renderPassType = renderPassType
    }

    // MARK: Internal

    func createNewRenderPass() throws -> any RenderPass {
        switch renderPassType {
        case .simple:
            try RenderPassSimple(
                device: device,
                drawablesPixelFormat: drawablesPixelFormat,
            )

        case .withIntermediateTexture:
            try RenderPassWithRegularIntermediateTexture(
                device: device,
                drawablesPixelFormat: drawablesPixelFormat,
            )

        case .tileMemory:
            try RenderPassTileMemory(
                device: device,
                drawablesPixelFormat: drawablesPixelFormat,
            )
        }
    }

    // MARK: Private

    private let device: MTLDevice

    private let drawablesPixelFormat: MTLPixelFormat
    private let renderPassType: RenderPassType

}
