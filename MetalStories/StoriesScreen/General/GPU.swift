import Metal
import MetalKit

// MARK: - GPU

final class GPU {

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

    enum GPUError: LocalizedError {
        case cantInitiateGPU
    }

    let device: MTLDevice
    let renderingCommandQueue: MTLCommandQueue
    let processingCommandQueue: MTLCommandQueue
}

extension GPU.GPUError {
    var errorDescription: String? {
        switch self {
        case .cantInitiateGPU:
            "Can't initiate GPU"
        }
    }
}
