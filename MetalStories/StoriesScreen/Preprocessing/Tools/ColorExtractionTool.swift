import Metal
import MetalPerformanceShaders


// MARK: - ColorExtractionTool

final class ColorExtractionTool {
    
    enum ColorExtractionToolError: LocalizedError {
        case failedToCreateBuffer
    }

    // MARK: Lifecycle

    init(device: MTLDevice) {
        self.device = device
        scaler = MPSImageBilinearScale(device: device)

        var histogramInfo = Self.makeHistogramInfo()
        histogram = MPSImageHistogram(
            device: device,
            histogramInfo: &histogramInfo,
        )
    }

    // MARK: Internal

    static let histogramBins = 128

    static func medianColor(from buffer: MTLBuffer) -> SIMD4<Float> {
        let histogramData = buffer.contents().bindMemory(
            to: UInt32.self,
            capacity: histogramBins * 4,
        )
        var medians = [Float](repeating: 0, count: 3)

        for channelIndex in 0..<3 {
            let channelStart = histogramData.advanced(by: histogramBins * channelIndex)
            var totalPixels: UInt64 = 0

            for level in 0..<histogramBins {
                totalPixels += UInt64(channelStart[level])
            }

            if totalPixels == 0 {
                continue
            }

            let midpoint = (totalPixels + 1) / 2
            var cumulative: UInt64 = 0

            for level in 0..<histogramBins {
                cumulative += UInt64(channelStart[level])
                if cumulative >= midpoint {
                    medians[channelIndex] = Float(level) / Float(histogramBins - 1)
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

    func makeHistogramBuffer(for pixelFormat: MTLPixelFormat) throws -> MTLBuffer {
        let size = histogram.histogramSize(forSourceFormat: pixelFormat)
        guard let buffer = device.makeBuffer(length: size, options: .storageModeShared) else {
            throw ColorExtractionToolError.failedToCreateBuffer
        }
        return buffer
    }

    func encode(
        commandBuffer: MTLCommandBuffer,
        sourceTexture: MTLTexture,
        topHistogramBuffer: MTLBuffer,
        bottomHistogramBuffer: MTLBuffer,
    ) throws {
        let histogramTexture = try createHistogramTexture(
            pixelFormat: sourceTexture.pixelFormat
        )

        scaler.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: histogramTexture,
        )

        let regions = histogramRegions(for: histogramTexture)

        encodeHistogram(
            region: regions.top,
            commandBuffer: commandBuffer,
            sourceTexture: histogramTexture,
            destination: topHistogramBuffer,
        )

        encodeHistogram(
            region: regions.bottom,
            commandBuffer: commandBuffer,
            sourceTexture: histogramTexture,
            destination: bottomHistogramBuffer,
        )
    }

    // MARK: Private

    private static let histogramTextureSize = 256

    private let device: MTLDevice
    private let histogram: MPSImageHistogram
    private let scaler: MPSImageBilinearScale

    private static func makeHistogramInfo() -> MPSImageHistogramInfo {
        MPSImageHistogramInfo(
            numberOfHistogramEntries: histogramBins,
            histogramForAlpha: false,
            minPixelValue: vector_float4(0, 0, 0, 1),
            maxPixelValue: vector_float4(1, 1, 1, 1),
        )
    }

    private func createHistogramTexture(
        pixelFormat: MTLPixelFormat
    ) throws -> MTLTexture {
        try TextureHelper.getTexture(
            device: device,
            pixelFormat: pixelFormat,
            width: Self.histogramTextureSize,
            height: Self.histogramTextureSize,
            storageMode: .private,
            usage: [.shaderWrite, .shaderRead],
        )
    }

    private func histogramRegions(
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

    private func encodeHistogram(
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

// MARK: - ColorExtractionToolError

extension ColorExtractionTool.ColorExtractionToolError {

    var errorDescription: String? {
        switch self {
        case .failedToCreateBuffer:
            "Failed to create histogram buffer."
        }
    }
}
