import Metal

enum PipelineStateObjects {
    static func simpleImagePipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat
    ) throws -> MTLRenderPipelineState {

        guard
            let vertexFunction = library.makeFunction(name: "vertex_general"),
            let fragmentFunction = library.makeFunction(name: "fragment_image")
        else {
            throw NSError()// TODO: throw normal error
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        descriptor.vertexBuffers[0].mutability = .immutable
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }
    
    static func simpleBackgroundPipeline(
        library: MTLLibrary,
        pixelFormat: MTLPixelFormat
    ) throws -> MTLRenderPipelineState {

        guard
            let vertexFunction = library.makeFunction(name: "vertex_general"),
            let fragmentFunction = library.makeFunction(name: "fragment_background")
        else {
            throw NSError()// TODO: throw normal error
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction

        descriptor.vertexBuffers[0].mutability = .immutable
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false

        return try library.device.makeRenderPipelineState(descriptor: descriptor)
    }
}
