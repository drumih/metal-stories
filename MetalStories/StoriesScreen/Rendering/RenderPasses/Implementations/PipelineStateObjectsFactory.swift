import Metal

// MARK: - PipelineStateObjectsFactory

enum PipelineStateObjectsFactory {

    // MARK: Internal

    enum PipelineStateObjectsFactoryError: LocalizedError {
        case failedToCreateFunction
    }

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
        filtersCount: Int16,
    ) throws -> MTLRenderPipelineState {
        let functionConstants = MTLFunctionConstantValues()
        var filtersCount = filtersCount
        functionConstants.setConstantValue(&filtersCount, type: .short, index: 0)
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_post_processing",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            fragmentConstantValues: functionConstants,
        )

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func imageTileMemoryPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_image_tile_memory",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func backgroundTileMemoryPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_background_tile_memory",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func postProcessingTileMemoryPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
        filtersCount: Int16,
    ) throws -> MTLRenderPipelineState {
        let functionConstants = MTLFunctionConstantValues()
        var filtersCount = filtersCount
        functionConstants.setConstantValue(&filtersCount, type: .short, index: 0)
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_post_processing_tile_memory",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            fragmentConstantValues: functionConstants,
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func imageDirectPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        depthAttachmentPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_image",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
        descriptor.depthAttachmentPixelFormat = depthAttachmentPixelFormat

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func backgroundDirectPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        depthAttachmentPixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_background",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
        )
        descriptor.depthAttachmentPixelFormat = depthAttachmentPixelFormat

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func postProcessingDirectPipeline(
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        depthAttachmentPixelFormat: MTLPixelFormat,
        filtersCount: Int16,
    ) throws -> MTLRenderPipelineState {
        let functionConstants = MTLFunctionConstantValues()
        var filtersCount = filtersCount
        functionConstants.setConstantValue(&filtersCount, type: .short, index: 0)
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_post_processing_tile_memory_direct",
            library: library,
            drawablesPixelFormat: drawablesPixelFormat,
            fragmentConstantValues: functionConstants,
        )
        descriptor.depthAttachmentPixelFormat = depthAttachmentPixelFormat

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    // MARK: Private

    private static func getBaseRenderPipelineDescriptor(
        vertexFunctionName: String,
        fragmentFunctionName: String,
        library: MTLLibrary,
        drawablesPixelFormat: MTLPixelFormat,
        fragmentConstantValues: MTLFunctionConstantValues? = nil,
    ) throws -> MTLRenderPipelineDescriptor {
        let vertexFunction = try makeFunction(
            library: library,
            name: vertexFunctionName,
        )
        let fragmentFunction = try makeFunction(
            library: library,
            name: fragmentFunctionName,
            constantValues: fragmentConstantValues,
        )

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        descriptor.vertexBuffers[0].mutability = .immutable
        descriptor.colorAttachments[0].pixelFormat = drawablesPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false

        return descriptor
    }

    private static func makeFunction(
        library: MTLLibrary,
        name: String,
        constantValues: MTLFunctionConstantValues? = nil,
    ) throws -> MTLFunction {
        if let constantValues {
            return try library.makeFunction(name: name, constantValues: constantValues)
        } else {
            if let function = library.makeFunction(name: name) {
                return function
            } else {
                throw PipelineStateObjectsFactoryError.failedToCreateFunction
            }
        }
    }
}

extension PipelineStateObjectsFactory.PipelineStateObjectsFactoryError {

    var errorDescription: String? {
        switch self {
        case .failedToCreateFunction:
            "Unable to create GPU shader function. The app may need to be reinstalled."
        }
    }
}
