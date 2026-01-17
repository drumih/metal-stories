import ImageIO
import Metal
import MetalKit
import MetalPerformanceShaders

// MARK: - MetalPreparationResult

struct MetalPreparationResult {
    let texture: MTLTexture
    let textureSize: SIMD2<Float>

    let topColor: SIMD4<Float>
    let bottomColor: SIMD4<Float>
}

// MARK: - PreprocessingError

enum PreprocessingError: LocalizedError {
    case failedToCreateTexture
    case failedToCreateBuffer
    case failedToCreateCommandBuffer

    var errorDescription: String? {
        switch self {
        case .failedToCreateTexture:
            "Failed to create Metal texture"
        case .failedToCreateBuffer:
            "Failed to create Metal buffer"
        case .failedToCreateCommandBuffer:
            "Failed to create command buffer"
        }
    }
}

// MARK: - CGImageToMetalTexturePreprocessing

enum CGImageToMetalTexturePreprocessing {

    // MARK: Internal

    static func prepareCGImage(
        cgImage: CGImage,
        orientation: CGImagePropertyOrientation,
        maxDimension: CGFloat,
        minDimension: CGFloat,
        gpu: GPU,
    ) throws -> MetalPreparationResult {
        let originalTexture = try getTexture(from: cgImage, device: gpu.device)
        let transformTool = try ImageTransformTool(device: gpu.device)

        let transformParams = orientation.imageTransformParams()

        let targetSize = calculateTargetSize(
            originalWidth: originalTexture.width,
            originalHeight: originalTexture.height,
            swapsDimensions: transformParams.swapsDimensions,
            maxDimension: maxDimension,
            minDimension: minDimension,
        )

        guard let destinationTexture = makeDestinationTexture(
            device: gpu.device,
            width: targetSize.width,
            height: targetSize.height,
            pixelFormat: originalTexture.pixelFormat,
        ) else {
            throw PreprocessingError.failedToCreateTexture
        }

        guard let histogramTexture = makeHistogramTexture(
            device: gpu.device,
            pixelFormat: destinationTexture.pixelFormat,
        ) else {
            throw PreprocessingError.failedToCreateTexture
        }

        var histogramInfo = makeHistogramInfo()
        let histogram = MPSImageHistogram(
            device: gpu.device,
            histogramInfo: &histogramInfo,
        )

        let histogramSize = histogram.histogramSize(
            forSourceFormat: histogramTexture.pixelFormat,
        )

        guard let topHistogramBuffer = gpu.device.makeBuffer(
            length: histogramSize,
            options: .storageModeShared,
        ) else {
            throw PreprocessingError.failedToCreateBuffer
        }

        guard let bottomHistogramBuffer = gpu.device.makeBuffer(
            length: histogramSize,
            options: .storageModeShared,
        ) else {
            throw PreprocessingError.failedToCreateBuffer
        }

        guard let commandBuffer = gpu.processingCommandQueue.makeCommandBuffer() else {
            throw PreprocessingError.failedToCreateCommandBuffer
        }

        let uvTransform = TransformCalculator.getUVTransform(
            sourceSize: SIMD2<Float>(
                Float(originalTexture.width),
                Float(originalTexture.height),
            ),
            destinationSize: SIMD2<Float>(
                Float(destinationTexture.width),
                Float(destinationTexture.height),
            ),
            rotationRadians: transformParams.rotationRadians,
            isMirrored: transformParams.isMirrored,
        )

        transformTool.encode(
            commandBuffer: commandBuffer,
            sourceTexture: originalTexture,
            destinationTexture: destinationTexture,
            uvTransform: uvTransform,
        )

        scaleTexture(
            from: destinationTexture,
            to: histogramTexture,
            device: gpu.device,
            commandBuffer: commandBuffer,
        )

        let regions = histogramRegions(for: histogramTexture)

        encodeHistogram(
            histogram,
            region: regions.top,
            commandBuffer: commandBuffer,
            sourceTexture: histogramTexture,
            destination: topHistogramBuffer,
        )

        encodeHistogram(
            histogram,
            region: regions.bottom,
            commandBuffer: commandBuffer,
            sourceTexture: histogramTexture,
            destination: bottomHistogramBuffer,
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        let topColor = medianColor(from: topHistogramBuffer)
        let bottomColor = medianColor(from: bottomHistogramBuffer)

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

    private static let histogramBins = 128
    private static let histogramTextureSize = 256

    private static func calculateTargetSize(
        originalWidth: Int,
        originalHeight: Int,
        swapsDimensions: Bool,
        maxDimension: CGFloat,
        minDimension: CGFloat,
    ) -> (width: Int, height: Int) {
        let rotatedWidth: Int
        let rotatedHeight: Int

        if swapsDimensions {
            rotatedWidth = originalHeight
            rotatedHeight = originalWidth
        } else {
            rotatedWidth = originalWidth
            rotatedHeight = originalHeight
        }

        let widthScale = CGFloat(rotatedWidth) / maxDimension
        let heightScale = CGFloat(rotatedHeight) / maxDimension
        let scaleFactor = max(widthScale, heightScale)

        var targetWidth = Int(CGFloat(rotatedWidth) / max(scaleFactor, 1.0))
        var targetHeight = Int(CGFloat(rotatedHeight) / max(scaleFactor, 1.0))

        let minScaleFactor = min(
            CGFloat(targetWidth) / minDimension,
            CGFloat(targetHeight) / minDimension,
        )
        if minScaleFactor < 1.0 {
            targetWidth = Int(CGFloat(targetWidth) / minScaleFactor)
            targetHeight = Int(CGFloat(targetHeight) / minScaleFactor)
        }

        return (max(1, targetWidth), max(1, targetHeight))
    }

    private static func makeDestinationTexture(
        device: MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat,
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false,
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderRead, .shaderWrite]

        return device.makeTexture(descriptor: descriptor)
    }

    private static func medianColor(from buffer: MTLBuffer) -> SIMD4<Float> {
        let histogramData = buffer.contents().bindMemory(
            to: UInt32.self,
            capacity: histogramBins * 4,
        )
        let channelStride = histogramBins
        var medians = [Float](repeating: 0, count: 3)

        for channelIndex in 0..<3 {
            let channelStart = histogramData.advanced(by: channelStride * channelIndex)
            var totalPixels: UInt64 = 0

            for level in 0..<channelStride {
                totalPixels += UInt64(channelStart[level])
            }

            if totalPixels == 0 {
                continue
            }

            let midpoint = (totalPixels + 1) / 2
            var cumulative: UInt64 = 0

            for level in 0..<channelStride {
                cumulative += UInt64(channelStart[level])
                if cumulative >= midpoint {
                    medians[channelIndex] = Float(level) / Float(channelStride - 1)
                    break
                }
            }
        }

        return SIMD4<Float>(
            medians[0],
            medians[1],
            medians[2],
            1.0,
        )
    }

    private static func getTexture(
        from cgImage: CGImage,
        device: MTLDevice,
    ) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)

        let originalTexture = try textureLoader.newTexture(
            cgImage: cgImage,
            options: [
                .SRGB: NSNumber(false),
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .origin: MTKTextureLoader.Origin.flippedVertically.rawValue as NSString,
            ],
        )

        return originalTexture
    }

    // TODO: unify with makeDestinationTexture. extract to special TextureHelper. use enum with static func. Find other places in app where texture creation is used. understand possible parameters. 
    private static func makeHistogramTexture(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: histogramTextureSize,
            height: histogramTextureSize,
            mipmapped: false,
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderWrite, .shaderRead]

        return device.makeTexture(descriptor: descriptor)
    }

    private static func scaleTexture(
        from sourceTexture: MTLTexture,
        to destinationTexture: MTLTexture,
        device: MTLDevice,
        commandBuffer: MTLCommandBuffer,
    ) {
        let scaler = MPSImageBilinearScale(device: device)
        scaler.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destinationTexture,
        )
    }

    private static func makeHistogramInfo() -> MPSImageHistogramInfo {
        MPSImageHistogramInfo(
            numberOfHistogramEntries: histogramBins,
            histogramForAlpha: false,
            minPixelValue: vector_float4(0, 0, 0, 1),
            maxPixelValue: vector_float4(1, 1, 1, 1),
        )
    }

    private static func histogramRegions(
        for texture: MTLTexture,
    ) -> (top: MTLRegion, bottom: MTLRegion) {
        let width = texture.width
        let height = texture.height
        let quarterHeight = height / 4

        let topRegion = MTLRegion(
            origin: .init(x: 0, y: 0, z: 0),
            size: .init(width: width, height: quarterHeight, depth: 1),
        )
        let bottomRegion = MTLRegion(
            origin: .init(x: 0, y: height - quarterHeight, z: 0),
            size: .init(width: width, height: quarterHeight, depth: 1),
        )

        return (topRegion, bottomRegion)
    }

    private static func encodeHistogram(
        _ histogram: MPSImageHistogram,
        region: MTLRegion,
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        destination: MTLBuffer,
    ) {
        histogram.clipRectSource = region
        histogram.encode(
            to: commandBuffer,
            sourceTexture: sourceTexture,
            histogram: destination,
            histogramOffset: 0,
        )
    }
}
