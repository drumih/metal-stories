import Metal
import simd

final class RenderPassWithRegularIntermediateTexture {

    private let gpu: GPU
    private let pixelFormat: MTLPixelFormat

    private let imageRenderPSO: MTLRenderPipelineState
    private let backgroundPSO: MTLRenderPipelineState
    private let postProcessingPSO: MTLRenderPipelineState

    private var intermediateTexture: MTLTexture?

    init(
        gpu: GPU,
        pixelFormat: MTLPixelFormat
    ) throws {
        self.gpu = gpu
        self.pixelFormat = pixelFormat
        let bundle = Bundle(for: RenderPassSimple.self)
        let library = try gpu.device.makeDefaultLibrary(bundle: bundle)
        self.imageRenderPSO = try PipelineStateObjectsSimple.imagePipeline(
            library: library,
            pixelFormat: pixelFormat
        )
        self.backgroundPSO = try PipelineStateObjectsSimple.backgroundPipeline(
            library: library,
            pixelFormat: pixelFormat
        )
        self.postProcessingPSO = try PipelineStateObjectsWithIntermediateTexture.postProcessingPipeline(
            library: library,
            pixelFormat: pixelFormat
        )
    }

    private func updateIntermediateTexture(forSize size: CGSize) {
        let texture = Self.makeTexture(
            device: gpu.device,
            pixelFormat: self.pixelFormat,
            width: Int(size.width),
            height: Int(size.height)
        )
        guard let texture else {
            assertionFailure()
            return
        }
        self.intermediateTexture = texture
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
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .renderTarget]
        return device.makeTexture(descriptor: descriptor)
    }
}

extension RenderPassWithRegularIntermediateTexture: RenderPass {

    func copy() throws -> any RenderPass {
        try Self(gpu: gpu, pixelFormat: pixelFormat)
    }
    
    func resize(size: CGSize) {
        updateIntermediateTexture(forSize: size)
    }

    func draw(
        commandBuffer: MTLCommandBuffer,
        descriptor: MTLRenderPassDescriptor, // TODO: rename to RenderPassDescriptor
        input: RenderPassInput
    ) {
        guard let intermediateTexture else {
            assertionFailure()
            return
        }

        let intermediatePassDescriptor = MTLRenderPassDescriptor()
        let intermediateAttachment = intermediatePassDescriptor.colorAttachments[0]
        intermediateAttachment?.texture = intermediateTexture
        intermediateAttachment?.loadAction = .dontCare
        intermediateAttachment?.storeAction = .store

        guard let intermediateRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: intermediatePassDescriptor) else {
            return
        }

        drawBackground(
            renderEncoder: intermediateRenderEncoder,
            topColor: input.topBackgroundColor,
            bottomColor: input.bottomBackgroundColor
        )
        drawImage(
            renderEncoder: intermediateRenderEncoder,
            texture: input.texture,
            transform: input.transform
        )

        intermediateRenderEncoder.endEncoding()

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        drawPostProcessing(
            renderEncoder: renderEncoder,
            offset: input.offset
        )
        
        renderEncoder.endEncoding()
    }
    
    private func drawPostProcessing(
        renderEncoder: MTLRenderCommandEncoder,
        offset: Float
    ) {
        renderEncoder.label = "Post Processing (with intermediate texture)"
        renderEncoder.setRenderPipelineState(postProcessingPSO)
        
        // TODO: explain this transform
        var transform = TransformCalculator.getFlippedVerticallyTransform()
        renderEncoder.setVertexBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0
        )
        renderEncoder.setFragmentTexture(
            intermediateTexture,
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
    
    // TODO: reuse from RenderPassSimple.swift
    private func drawImage(
        renderEncoder: MTLRenderCommandEncoder,
        texture: MTLTexture,
        transform: float4x4
    ) {
        renderEncoder.label = "Draw Image (with intermediate texture)"
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

    // TODO: reuse from RenderPassSimple.swift
    private func drawBackground(
        renderEncoder: MTLRenderCommandEncoder,
        topColor: SIMD4<Float>,
        bottomColor: SIMD4<Float>
    ) {
        renderEncoder.label = "Draw Background (with intermediate texture)"
        renderEncoder.setRenderPipelineState(backgroundPSO)
        
        var transform = matrix_identity_float4x4
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
