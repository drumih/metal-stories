import Metal

enum PipelineStateObjectsTileMemory {
    static func imagePipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat _: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        guard
            let vertexFunction = library.makeFunction(name: "vertex_general"),
            let fragmentFunction = library.makeFunction(name: "fragment_image_tile_memory")
        else {
            throw NSError() // TODO: throw normal error
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        descriptor.vertexBuffers[0].mutability = .immutable
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false

        descriptor.colorAttachments[1].pixelFormat = .bgra8Unorm
        descriptor.depthAttachmentPixelFormat = .depth32Float

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func backgroundPipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        guard
            let vertexFunction = library.makeFunction(name: "vertex_general"),
            let fragmentFunction = library.makeFunction(name: "fragment_background_tile_memory")
        else {
            throw NSError() // TODO: throw normal error
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        descriptor.vertexBuffers[0].mutability = .immutable
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false

        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false

        descriptor.depthAttachmentPixelFormat = .depth32Float

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }

    static func postProcessingPipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat,
        memorylessTexturePixelFormat: MTLPixelFormat,
    ) throws -> MTLRenderPipelineState {
        guard
            let vertexFunction = library.makeFunction(name: "vertex_general"),
            let fragmentFunction = library.makeFunction(name: "fragment_post_processing_tile_memory")
        else {
            throw NSError() // TODO: throw normal error
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        descriptor.vertexBuffers[0].mutability = .immutable
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false

        descriptor.colorAttachments[1].pixelFormat = memorylessTexturePixelFormat
        descriptor.colorAttachments[1].isBlendingEnabled = false

        descriptor.depthAttachmentPixelFormat = .depth32Float

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }
}
