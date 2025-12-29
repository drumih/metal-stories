import Metal
import MetalKit
import CoreImage
import MetalPerformanceShaders

// TODO: find better name
struct MetalPreparationResult {
    let texture: MTLTexture
    let topColor: SIMD3<Float>
    let bottomColor: SIMD3<Float>
}

enum CGImageToMetalTexturePreprocessing {
    
    private static let histogramTextureSize: Int = 128
    
    static func prepareCGImage(
        cgImage: CGImage,
        gpu: GPU
    ) throws -> MetalPreparationResult {
        let textureLoader = MTKTextureLoader(device: gpu.device)
        
        let metalTexture = try textureLoader.newTexture(
            cgImage: cgImage,
            options: [
                .SRGB: NSNumber(false),
                .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
                .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue),
                .origin: (MTKTextureLoader.Origin.flippedVertically.rawValue as NSString)
            ]
        )
        
        var topColor: SIMD3<Float>?
        var bottomColor: SIMD3<Float>?

        if
            let intermediateTexture = getHistogramTexture(device: gpu.device, pixelFormat: metalTexture.pixelFormat),
            let commandBuffer = gpu.processingCommandQueue.makeCommandBuffer()
        {
            
            let scaler = MPSImageBilinearScale(device: gpu.device)
            scaler.encode(
                commandBuffer: commandBuffer,
                sourceTexture: metalTexture,
                destinationTexture: intermediateTexture
            )
            
            var info = MPSImageHistogramInfo(
                numberOfHistogramEntries: 128,
                histogramForAlpha: false,
                minPixelValue: vector_float4(0,0,0,1),
                maxPixelValue: vector_float4(1,1,1,1)
            )
            let histogram = MPSImageHistogram(device: gpu.device, histogramInfo: &info)

            let histSize = histogram.histogramSize(forSourceFormat: intermediateTexture.pixelFormat)
            let histTopBuffer = gpu.device.makeBuffer(length: histSize, options: .storageModeShared)!
            let histBottomBuffer = gpu.device.makeBuffer(length: histSize, options: .storageModeShared)!
            
            let width = 128
            let height = 128
            let quarterHeight = height / 4
            let topRegion = MTLRegion(
                origin: .init(x: 0, y: 0, z: 0),
                size: .init(width: width, height: quarterHeight, depth: 1)
            )
            let bottomRegion = MTLRegion(
                origin: .init(x: 0, y: height - quarterHeight, z: 0),
                size: .init(width: width, height: quarterHeight, depth: 1)
            )
            
            histogram.clipRectSource = topRegion
            histogram.encode(
                to: commandBuffer,
                sourceTexture: intermediateTexture,
                histogram: histTopBuffer,
                histogramOffset: 0
            )
            

            histogram.clipRectSource = bottomRegion
            histogram.encode(
                to: commandBuffer,
                sourceTexture: intermediateTexture,
                histogram: histBottomBuffer,
                histogramOffset: 0
            )
            
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            
            
            let medTopRGB = medianRGBFromHistogramBuffer(histTopBuffer)
            let medBottomRGB = medianRGBFromHistogramBuffer(histBottomBuffer)
            
            topColor = SIMD3<Float>(
                Float(medTopRGB.x) / 255.0,
                Float(medTopRGB.y) / 255.0,
                Float(medTopRGB.z) / 255.0
            )
            bottomColor = SIMD3<Float>(
                Float(medBottomRGB.x) / 255.0,
                Float(medBottomRGB.y) / 255.0,
                Float(medBottomRGB.z) / 255.0
            )
        }

        return .init(
            texture: metalTexture,
            topColor: topColor ?? .init(0.7, 0.7, 0.7),
            bottomColor: bottomColor ?? .init(0.4, 0.4, 0.4)
        )
    }
    
    private static func medianRGBFromHistogramBuffer(_ buffer: MTLBuffer) -> SIMD3<UInt8> {
        let histogramData = buffer.contents().bindMemory(to: UInt32.self, capacity: 3*128)
        
        func findMedianValue(in channelHistogram: UnsafePointer<UInt32>) -> UInt8 {
            var totalPixels: UInt64 = 0
            for i in 0..<128 {
                totalPixels += UInt64(channelHistogram[i])
            }
            let halfPixels = totalPixels / 2
            var cumulativeCount: UInt64 = 0
            for intensityLevel in 0..<128 {
                cumulativeCount += UInt64(channelHistogram[intensityLevel])
                if cumulativeCount >= halfPixels {
                    return UInt8(intensityLevel)
                }
            }
            return 255
        }
        
        let redMedian = findMedianValue(in: histogramData + 0*128)
        let greenMedian = findMedianValue(in: histogramData + 1*128)
        let blueMedian = findMedianValue(in: histogramData + 2*128)
        
        return SIMD3(redMedian, greenMedian, blueMedian)
    }
    
    private static func getHistogramTexture(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: 128,
            height: 128,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.shaderWrite, .shaderRead]
        
        return device.makeTexture(descriptor: descriptor)
    }
}
