import Metal
import simd

// MARK: - ImageTransform

final class ImageTransform {

    // MARK: Lifecycle

    init(device: MTLDevice, pixelFormat: MTLPixelFormat) throws {
        let bundle = Bundle(for: ImageTransform.self)
        guard let library = try? device.makeDefaultLibrary(bundle: bundle) else {
            throw ImageTransformError.failedToCreateLibrary
        }

        renderPipeline = try PipelineStateObjectsFactory.imageBasePipeline(
            library: library,
            drawablesPixelFormat: pixelFormat,
        )
    }

    // MARK: Internal

    enum ImageTransformError: LocalizedError {
        case failedToCreateLibrary
        case failedToEncode
    }

    func encode(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture,
        positionTransform: float4x4,
    ) throws {
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .dontCare
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard
            let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: renderPassDescriptor
            )
        else {
            throw ImageTransformError.failedToEncode
        }

        encoder.setRenderPipelineState(renderPipeline)
        encoder.setFragmentTexture(sourceTexture, index: 0)

        var transform = positionTransform
        encoder.setVertexBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0,
        )

        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
    }

    // MARK: Private

    private let renderPipeline: MTLRenderPipelineState

}

extension ImageTransform.ImageTransformError {

    var errorDescription: String? {
        switch self {
        case .failedToEncode:
            "Unable to encode"
        case .failedToCreateLibrary:
            "Unable to create GPU shader library."
        }
    }
}
