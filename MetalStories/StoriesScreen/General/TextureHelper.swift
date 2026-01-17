import Metal

// MARK: - TextureHelper

enum TextureHelper {
    enum TextureHelperError: LocalizedError {
        case failedToCreateTexture
    }

    static func getTexture(
        device: MTLDevice,
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int,
        storageMode: MTLStorageMode,
        usage: MTLTextureUsage,
    ) throws -> MTLTexture {
        guard width > 0, height > 0 else {
            throw TextureHelperError.failedToCreateTexture
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false,
        )
        descriptor.storageMode = storageMode
        descriptor.usage = usage

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TextureHelperError.failedToCreateTexture
        }
        return texture
    }
}

extension TextureHelper.TextureHelperError {
    var errorDescription: String? {
        switch self {
        case .failedToCreateTexture:
            "Failed to create Metal texture"
        }
    }
}
