import ImageIO
import Metal
import MetalKit

// MARK: - MetalPreparationResult

struct MetalPreparationResult {
    let texture: MTLTexture
    let textureSize: SIMD2<Float>

    let topColor: SIMD4<Float>
    let bottomColor: SIMD4<Float>
}

// MARK: - CGImageToMetalTexturePreprocessing

enum CGImageToMetalTexturePreprocessing {

    // MARK: Internal

    enum PreprocessingError: LocalizedError {
        case imageTooSmall
        case failedToCreateBuffer
        case failedToCreateCommandBuffer
    }

    static func prepareCGImage(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        targetDimension: Int,
        minPossibleDimension: Int,
        gpu: GPU,
    ) throws -> MetalPreparationResult {
        if cgImage.width < minPossibleDimension || cgImage.height < minPossibleDimension {
            throw PreprocessingError.imageTooSmall
        }

        let originalTexture = try getOriginalTexture(from: cgImage, device: gpu.device)

        // tools allocation

        let imageTransform = try ImageTransform(
            device: gpu.device,
            pixelFormat: originalTexture.pixelFormat,
        )
        let colorExtraction = ColorExtraction(device: gpu.device)

        // transform calculation

        let transformParams = orientation.imageTransformParams()

        let targetSize = calculateTargetSize(
            originalWidth: originalTexture.width,
            originalHeight: originalTexture.height,
            swapsDimensions: transformParams.swapsDimensions,
            targetDimension: targetDimension,
        )

        let positionTransform = TransformCalculator.getUVTransform(
            rotationRadians: transformParams.rotationRadians,
            isMirrored: transformParams.isMirrored,
            isFlipped: true,
        )

        // resources allocation

        let destinationTexture = try TextureHelper.getTexture(
            device: gpu.device,
            pixelFormat: originalTexture.pixelFormat,
            width: targetSize.width,
            height: targetSize.height,
            storageMode: .private,
            usage: [.shaderRead, .renderTarget],
        )

        let topHistogramBuffer = try colorExtraction.makeHistogramBuffer(
            for: destinationTexture.pixelFormat
        )

        let bottomHistogramBuffer = try colorExtraction.makeHistogramBuffer(
            for: destinationTexture.pixelFormat
        )

        // GPU encoding

        guard let commandBuffer = gpu.processingCommandQueue.makeCommandBuffer() else {
            throw PreprocessingError.failedToCreateCommandBuffer
        }

        try imageTransform.encode(
            commandBuffer: commandBuffer,
            sourceTexture: originalTexture,
            destinationTexture: destinationTexture,
            positionTransform: positionTransform,
        )

        try colorExtraction.encode(
            commandBuffer: commandBuffer,
            sourceTexture: destinationTexture,
            topHistogramBuffer: topHistogramBuffer,
            bottomHistogramBuffer: bottomHistogramBuffer,
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // postprocessing

        let topColor = ColorExtraction.medianColor(from: topHistogramBuffer)
        let bottomColor = ColorExtraction.medianColor(from: bottomHistogramBuffer)

        let textureSize = SIMD2<Float>(
            Float(destinationTexture.width),
            Float(destinationTexture.height),
        )

        return MetalPreparationResult(
            texture: destinationTexture,
            textureSize: textureSize,
            topColor: topColor,
            bottomColor: bottomColor,
        )
    }

    // MARK: Private

    private static func calculateTargetSize(
        originalWidth: Int,
        originalHeight: Int,
        swapsDimensions: Bool,
        targetDimension: Int,
    ) -> (width: Int, height: Int) {
        let rotatedWidth = swapsDimensions ? originalHeight : originalWidth
        let rotatedHeight = swapsDimensions ? originalWidth : originalHeight

        let rotatedWidthF = CGFloat(rotatedWidth)
        let rotatedHeightF = CGFloat(rotatedHeight)
        let targetDimensionF = CGFloat(targetDimension)

        let targetWidth: Int
        let targetHeight: Int

        if rotatedWidth >= rotatedHeight {
            targetWidth = targetDimension
            targetHeight = Int((rotatedHeightF * targetDimensionF / rotatedWidthF)
                .rounded(.toNearestOrAwayFromZero))
        } else {
            targetWidth = Int((rotatedWidthF * targetDimensionF / rotatedHeightF)
                .rounded(.toNearestOrAwayFromZero))
            targetHeight = targetDimension
        }

        return (max(1, targetWidth), max(1, targetHeight))
    }

    private static func getOriginalTexture(
        from cgImage: CGImage,
        device: MTLDevice,
    ) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)

        return try textureLoader.newTexture(
            cgImage: cgImage,
            options: [
                .SRGB: NSNumber(false),
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .origin: MTKTextureLoader.Origin.flippedVertically.rawValue as NSString,
            ],
        )
    }
}

extension CGImageToMetalTexturePreprocessing.PreprocessingError {

    var errorDescription: String? {
        switch self {
        case .imageTooSmall:
            "Image too small"
        case .failedToCreateBuffer:
            "Failed to create Metal buffer"
        case .failedToCreateCommandBuffer:
            "Failed to create command buffer"
        }
    }
}
