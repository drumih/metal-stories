import Metal
import MetalKit

final class GPU {
    
    static var `default`: GPU = GPU()!
    
    let device: MTLDevice
    let renderingCommandQueue: MTLCommandQueue
    let processingCommandQueue: MTLCommandQueue
    
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
}
