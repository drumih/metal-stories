import Metal
import simd

// MARK: - ImageTransformTool

// TODO: use fragment_image and vertex_general. just render it to offscreen texture instead of kernel shader
final class ImageTransformTool {

    // MARK: Lifecycle

    init(device: MTLDevice) throws {
        let bundle = Bundle(for: ImageTransformTool.self)
        guard
            let library = try? device.makeDefaultLibrary(bundle: bundle),
            let function = library.makeFunction(name: "imageTransform")
        else {
            throw ImageTransformToolError.failedToCreateFunction
        }

        computePipeline = try device.makeComputePipelineState(function: function)
    }

    // MARK: Internal

    enum ImageTransformToolError: LocalizedError {
        case failedToCreateFunction
    }

    func encode(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destinationTexture: MTLTexture,
        uvTransform: float4x4,
    ) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            return
        }

        encoder.setComputePipelineState(computePipeline)
        encoder.setTexture(sourceTexture, index: 0)
        encoder.setTexture(destinationTexture, index: 1)

        var transform = uvTransform
        encoder.setBytes(
            &transform,
            length: MemoryLayout<float4x4>.stride,
            index: 0,
        )

        let gridSize = MTLSize(
            width: destinationTexture.width,
            height: destinationTexture.height,
            depth: 1,
        )

        let threadGroupSize = getThreadGroupSize()

        encoder.dispatchThreads(
            gridSize,
            threadsPerThreadgroup: threadGroupSize,
        )
        encoder.endEncoding()
    }

    // MARK: Private

    private let computePipeline: MTLComputePipelineState

    private func getThreadGroupSize() -> MTLSize {
        let threadGroupWidth = computePipeline.threadExecutionWidth
        let threadGroupHeight = computePipeline.maxTotalThreadsPerThreadgroup / threadGroupWidth
        return MTLSize(
            width: threadGroupWidth,
            height: threadGroupHeight,
            depth: 1,
        )
    }
}

extension ImageTransformTool.ImageTransformToolError {

    var errorDescription: String? {
        switch self {
        case .failedToCreateFunction:
            "Unable to create GPU shader function 'imageTransform'."
        }
    }
}
