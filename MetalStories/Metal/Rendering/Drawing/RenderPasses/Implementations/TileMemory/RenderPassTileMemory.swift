import Metal
import simd

final class RenderPassTileMemory {

    private let gpu: GPU
    private let pixelFormat: MTLPixelFormat
    private let intermediateTexturePixelFormat: MTLPixelFormat
    private let depthTexturePixelFormat: MTLPixelFormat
    
    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState
    private let postProcessingPSO: MTLRenderPipelineState
    
    private let depthStencilState: MTLDepthStencilState
    private let postProcessingDepthStencilState: MTLDepthStencilState

    private var intermediateTexture: MTLTexture?
    private var depthTexture: MTLTexture?

    init(
        gpu: GPU,
        pixelFormat: MTLPixelFormat
    ) throws {
        self.gpu = gpu
        self.pixelFormat = pixelFormat
        self.intermediateTexturePixelFormat = pixelFormat
        self.depthTexturePixelFormat = .depth32Float
        let bundle = Bundle(for: RenderPassSimple.self)
        let library = try gpu.device.makeDefaultLibrary(bundle: bundle)
        self.imageRenderPSO = try PipelineStateObjectsTileMemory.imagePipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat
        )
        self.backgroundPSO = try PipelineStateObjectsTileMemory.backgroundPipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat
        )
        self.postProcessingPSO = try PipelineStateObjectsTileMemory.postProcessingPipeline(
            library: library,
            pixelFormat: pixelFormat,
            memorylessTexturePixelFormat: pixelFormat
        )

        self.depthStencilState = try Self.makeDepthStencilState(device: gpu.device)
        self.postProcessingDepthStencilState = try Self.makePostProcessingDepthStencilState(device: gpu.device)
    }

    private static func makeDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less // TODO: double check
        descriptor.isDepthWriteEnabled = true
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw NSError() // TODO: throw normal error
        }
        return stencilState
    }

    // TODO: do we really need it?
    private static func makePostProcessingDepthStencilState(device: MTLDevice) throws -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.isDepthWriteEnabled = false
        guard let stencilState = device.makeDepthStencilState(descriptor: descriptor) else {
            throw NSError() // TODO: throw normal error
        }
        return stencilState
    }

    private func updateIntermediateTexture(forSize size: CGSize) {
        let texture = Self.makeTexture(
            device: gpu.device,
            pixelFormat: self.pixelFormat,
            width: Int(size.width),
            height: Int(size.height)
        )
        let depthTexture = Self.makeTexture(
            device: gpu.device,
            pixelFormat: .depth32Float,
            width: Int(size.width),
            height: Int(size.height)
        )
        guard let texture, let depthTexture else {
            assertionFailure()
            return
        }
        self.intermediateTexture = texture
        self.depthTexture = depthTexture
    }

    private static func makeTexture(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .memoryless
        descriptor.usage = [.shaderRead, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }
}

extension RenderPassTileMemory: RenderPass {

    func copy() throws -> any RenderPass {
        try Self(gpu: gpu, pixelFormat: pixelFormat)
    }
    
    func resize(size: CGSize) {
        updateIntermediateTexture(forSize: size)
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        renderPassDescriptor rpd: MTLRenderPassDescriptor,
        input: RenderPassInput
    ) {
        guard let intermediateTexture, let depthTexture else {
            assertionFailure()
            return
        }

        rpd.colorAttachments[1]?.texture = intermediateTexture
        rpd.colorAttachments[1]?.loadAction = .dontCare
        rpd.colorAttachments[1]?.storeAction = .dontCare
        
        rpd.depthAttachment.texture = depthTexture
        rpd.depthAttachment.storeAction = .dontCare

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: rpd) else {
            return
        }

        renderEncoder.setDepthStencilState(depthStencilState)
        
        // pay attention to the order
        drawImage(
            renderEncoder: renderEncoder,
            texture: input.imageTexture,
            transform: input.transform
        )
        drawBackground(
            renderEncoder: renderEncoder,
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor
        )

        renderEncoder.setDepthStencilState(postProcessingDepthStencilState)
        drawPostProcessing(
            renderEncoder: renderEncoder,
            offset: input.filterPositionOffset
        )
        
        renderEncoder.endEncoding()
    }
    
    private func drawPostProcessing(
        renderEncoder: MTLRenderCommandEncoder,
        offset: Float
    ) {
        renderEncoder.label = "Post Processing (Tile Memory)"
        renderEncoder.setRenderPipelineState(postProcessingPSO)

        var transform = TransformCalculator.getIdentityTransform()
        renderEncoder.setVertexBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0
        )
        var offset = offset
        renderEncoder.setFragmentBytes(
            &offset,
            length: MemoryLayout<Float>.stride,
            index: 0
        )
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
    
    private func drawImage(
        renderEncoder: MTLRenderCommandEncoder,
        texture: MTLTexture,
        transform: float4x4
    ) {
        renderEncoder.label = "Draw Image (Tile Memory)"
        renderEncoder.setRenderPipelineState(imageRenderPSO)

        var transform = transform
        renderEncoder.setVertexBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0
        )
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }

    private func drawBackground(
        renderEncoder: MTLRenderCommandEncoder,
        topColor: SIMD4<Float>,
        bottomColor: SIMD4<Float>
    ) {
        renderEncoder.label = "Draw Background (Tile Memory)"
        renderEncoder.setRenderPipelineState(backgroundPSO)

        // TODO: check, if translation needed here
        var transform = TransformCalculator.getIdentityTransform()
        renderEncoder.setVertexBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0
        )
        var topColor = topColor
        renderEncoder.setFragmentBytes(
            &topColor,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 0
        )
        var bottomColor = bottomColor
        renderEncoder.setFragmentBytes(
            &bottomColor,
            length: MemoryLayout<SIMD4<Float>>.stride,
            index: 1
        )
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
    }
}
