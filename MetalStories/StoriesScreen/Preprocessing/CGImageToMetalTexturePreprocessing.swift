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

// MARK: - CGImageToMetalTexturePreprocessing

enum CGImageToMetalTexturePreprocessing {

    // MARK: Internal

    static func prepareCGImage(
        cgImage: CGImage,
        gpu: GPU,
    ) throws -> MetalPreparationResult {
        let metalTexture = try makeTexture(from: cgImage, device: gpu.device)
        let textureSize = SIMD2<Float>(
            .init(metalTexture.width),
            .init(metalTexture.height)
        )
        let gradientColors = computeEdgeMedianColors(for: metalTexture, gpu: gpu)

        return .init(
            texture: metalTexture,
            textureSize: textureSize,
            topColor: gradientColors?.top ?? defaultTopColor,
            bottomColor: gradientColors?.bottom ?? defaultBottomColor,
        )
    }

    // MARK: Private

    private static let histogramBins = 128
    private static let histogramTextureSize = 256

    private static let defaultTopColor = SIMD4<Float>(0.7, 0.7, 0.7, 1.0)
    private static let defaultBottomColor = SIMD4<Float>(0.4, 0.4, 0.4, 1.0)

    private static func computeEdgeMedianColors(
        for texture: MTLTexture,
        gpu: GPU,
    ) -> (top: SIMD4<Float>, bottom: SIMD4<Float>)? {
        guard
            let histogramTexture = getHistogramTexture(
                device: gpu.device,
                pixelFormat: texture.pixelFormat,
            ),
            let commandBuffer = gpu.processingCommandQueue.makeCommandBuffer()
        else {
            return nil
        }

        scaleTexture(
            from: texture,
            to: histogramTexture,
            device: gpu.device,
            commandBuffer: commandBuffer,
        )

        var histogramInfo = makeHistogramInfo()
        let histogram = MPSImageHistogram(
            device: gpu.device,
            histogramInfo: &histogramInfo,
        )

        let histogramSize = histogram.histogramSize(
            forSourceFormat: histogramTexture.pixelFormat
        )

        guard
            let topBuffer = gpu.device.makeBuffer(
                length: histogramSize,
                options: .storageModeShared,
            ),
            let bottomBuffer = gpu.device.makeBuffer(
                length: histogramSize,
                options: .storageModeShared,
            )
        else {
            return nil
        }

        let regions = histogramRegions(for: histogramTexture)

        encodeHistogram(
            histogram,
            region: regions.top,
            commandBuffer: commandBuffer,
            sourceTexture: histogramTexture,
            destination: topBuffer,
        )

        encodeHistogram(
            histogram,
            region: regions.bottom,
            commandBuffer: commandBuffer,
            sourceTexture: histogramTexture,
            destination: bottomBuffer,
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return (
            medianColor(from: topBuffer),
            medianColor(from: bottomBuffer),
        )
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

    private static func makeTexture(
        from cgImage: CGImage,
        device: MTLDevice,
    ) throws -> MTLTexture {
        let textureLoader = MTKTextureLoader(device: device)

        // TODO: fix some images loading!
        let texture = try textureLoader.newTexture(
            cgImage: cgImage,
            options: [
                .SRGB: NSNumber(false),
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .origin: MTKTextureLoader.Origin.flippedVertically.rawValue as NSString,
            ],
        )

        // textureLoader bugfix
        guard cgImage.alphaInfo == .noneSkipFirst else {
            return texture
        }

        let swizzle = MTLTextureSwizzleChannels(
            red: .green,
            green: .red,
            blue: .alpha,
            alpha: .one,
        )

        let swizzledTexture = texture.makeTextureView(
            pixelFormat: .bgra8Unorm,
            textureType: texture.textureType,
            levels: 0..<texture.mipmapLevelCount,
            slices: 0..<texture.arrayLength,
            swizzle: swizzle,
        )

        guard let swizzledTexture else {
            throw ImagePreprocessingError.failedToCreateTexture
        }

        return swizzledTexture
    }

    private static func getHistogramTexture(
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
        for texture: MTLTexture
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
