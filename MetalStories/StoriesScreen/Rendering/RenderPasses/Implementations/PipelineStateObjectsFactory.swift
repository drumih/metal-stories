import Metal

enum PipelineStateObjectsFactoryError: Error {
    case failedToCreateFunction(name: String)
}

enum PipelineStateObjectsFactory {
    // MARK: Base
    
    static func imageBasePipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {

        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_image",
            library: library,
            pixelFormatForMainAttachment: pixelFormat
        )

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func backgroundBasePipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {

        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_background",
            library: library,
            pixelFormatForMainAttachment: pixelFormat
        )

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    static func postProcessingBasePipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_post_processing",
            library: library,
            pixelFormatForMainAttachment: pixelFormat
        )

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    // MARK: Tile Memory
    
    static func imageTileMemoryPipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {

        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_image_tile_memory",
            library: library,
            pixelFormatForMainAttachment: pixelFormat
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false
        descriptor.depthAttachmentPixelFormat = .depth32Float

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func backgroundTileMemoryPipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_background_tile_memory",
            library: library,
            pixelFormatForMainAttachment: pixelFormat
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false
        descriptor.depthAttachmentPixelFormat = .depth32Float

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func postProcessingTileMemoryPipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        let descriptor = try getBaseRenderPipelineDescriptor(
            vertexFunctionName: "vertex_general",
            fragmentFunctionName: "fragment_post_processing_tile_memory",
            library: library,
            pixelFormatForMainAttachment: pixelFormat
        )
        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false
        descriptor.depthAttachmentPixelFormat = .depth32Float

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    // MARK: helpers
    
    private static func getBaseRenderPipelineDescriptor(
        vertexFunctionName: String,
        fragmentFunctionName: String,
        library: MTLLibrary,
        pixelFormatForMainAttachment: MTLPixelFormat
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
        descriptor.colorAttachments[0].pixelFormat = pixelFormatForMainAttachment
        descriptor.colorAttachments[0].isBlendingEnabled = false

        return descriptor
    }
}
