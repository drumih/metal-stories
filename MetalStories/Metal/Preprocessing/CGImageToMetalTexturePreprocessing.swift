import Metal
import MetalKit
import CoreImage

// TODO: find better name
struct MetalPreparationResult {
    let texture: MTLTexture
    let topColor: SIMD3<Float>
    let bottomColor: SIMD3<Float>
}

enum CGImageToMetalTexturePreprocessing {
    
    static func prepareCGImage(
        cgImage: CGImage,
        gpu: GPU = GPU.default
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

        return .init(
            texture: metalTexture,
            topColor: .init(0, 1, 0),
            bottomColor: .init(1, 0, 0)
        )
    }
}
