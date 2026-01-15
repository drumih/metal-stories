import Metal

// MARK: - RenderPassType

enum RenderPassType: Int {
    case simple
    case withIntermediateTexture
    case tileMemory
    case tileMemoryFetch // TODO: rename?
}

// MARK: - RenderPassFactory

final class RenderPassFactory {

    // MARK: Lifecycle

    init(
        device: MTLDevice,
        drawablesPixelFormat: MTLPixelFormat,
        renderPassType: RenderPassType,
        availableFilterCount: Int16
    ) {
        self.device = device
        self.drawablesPixelFormat = drawablesPixelFormat
        self.renderPassType = renderPassType
        self.availableFilterCount = availableFilterCount
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
                availableFilterCount: availableFilterCount,
            )

        case .tileMemory:
            try RenderPassTileMemory(
                device: device,
                drawablesPixelFormat: drawablesPixelFormat,
                availableFilterCount: availableFilterCount,
            )

        case .tileMemoryFetch:
            try RenderPassDirect(
                device: device,
                drawablesPixelFormat: drawablesPixelFormat,
                availableFilterCount: availableFilterCount,
            )
        }
    }

    // MARK: Private

    private let device: MTLDevice

    private let drawablesPixelFormat: MTLPixelFormat
    private let renderPassType: RenderPassType
    private let availableFilterCount: Int16

}
