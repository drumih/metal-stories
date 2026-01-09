import Metal
import MetalKit

// TODO: remove it later
final class GPU {

    // MARK: Lifecycle

    init?() {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let renderingCommandQueue = device.makeCommandQueue(),
            let processingCommandQueue = device.makeCommandQueue()
        else {
            return nil
        }
        self.device = device
        self.renderingCommandQueue = renderingCommandQueue
        self.processingCommandQueue = processingCommandQueue
    }

    // MARK: Internal

    static var `default` = GPU()!

    let device: MTLDevice
    let renderingCommandQueue: MTLCommandQueue
    let processingCommandQueue: MTLCommandQueue
}
