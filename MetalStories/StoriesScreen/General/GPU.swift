import Metal
import MetalKit

final class GPU {
    
    enum GPUError: LocalizedError {
        case cantInitiateGPU
    }

    // MARK: Lifecycle

    init() throws {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let renderingCommandQueue = device.makeCommandQueue(),
            let processingCommandQueue = device.makeCommandQueue()
        else {
            throw GPUError.cantInitiateGPU
        }
        self.device = device
        self.renderingCommandQueue = renderingCommandQueue
        self.processingCommandQueue = processingCommandQueue
    }

    // MARK: Internal

    let device: MTLDevice
    let renderingCommandQueue: MTLCommandQueue
    let processingCommandQueue: MTLCommandQueue
}

extension GPU.GPUError {
    var errorDescription: String? {
        switch self {
        case .cantInitiateGPU:
            return "Can't initiate GPU"
        }
    }
}
