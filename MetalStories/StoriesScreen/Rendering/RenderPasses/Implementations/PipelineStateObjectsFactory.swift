import Metal

// MARK: - PipelineStateObjectsFactoryError

enum PipelineStateObjectsFactoryError: LocalizedError {
    case failedToCreateFunction(name: String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateFunction(let name):
            "Unable to create GPU shader function '\(name)'. The app may need to be reinstalled."
        }
    }
}

// MARK: - PipelineStateObjectsFactory

enum PipelineStateObjectsFactory {

    // MARK: Internal

    static func imageBasePipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_image",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func backgroundBasePipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_background",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func postProcessingBasePipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_post_processing",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func imageTileMemoryPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
        depthAttachmentPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_image_tile_memory",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false
        descriptor.depthAttachmentPixelFormat = depthAttachmentPixelFormat

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func backgroundTileMemoryPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
        depthAttachmentPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_background_tile_memory",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false
        descriptor.depthAttachmentPixelFormat = depthAttachmentPixelFormat

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func postProcessingTileMemoryPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
        depthAttachmentPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_post_processing_tile_memory",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false
        descriptor.depthAttachmentPixelFormat = depthAttachmentPixelFormat

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    // MARK: Private

    private static func getBaseRenderPipelineDescriptor(
        vertexFunctionName: String,
        fragmentFunctionName: String,
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineDescriptor {
        guard let vertexFunction = library.makeFunction(name: vertexFunctionName) else {
            throw PipelineStateObjectsFactoryError.failedToCreateFunction(name: vertexFunctionName)
        }
        guard let fragmentFunction = library.makeFunction(name: fragmentFunctionName) else {
            throw PipelineStateObjectsFactoryError.failedToCreateFunction(name: fragmentFunctionName)
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        descriptor.vertexBuffers[0].mutability = .immutable
        descriptor.colorAttachments[0].pixelFormat = drawablesPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false

        return descriptor
    }
}
