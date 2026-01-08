import CoreGraphics
import Foundation
import Metal

// MARK: - CGImageFromMetalTextureError

enum CGImageFromMetalTextureError: LocalizedError {
    case unsupportedPixelFormat
    case failedToCreateDataProvider
    case failedToCreateImage

    var errorDescription: String? {
        switch self {
        case .unsupportedPixelFormat:
            return "The image format is not supported for export."
        case .failedToCreateDataProvider:
            return "Unable to read the rendered image data."
        case .failedToCreateImage:
            return "Unable to create the final image for export."
        }
    }
}

// MARK: - CGImageFromMetalTexture

enum CGImageFromMetalTexture {
    static func getCGImage(
        from metalTexture: MTLTexture,
        colorSpace: CGColorSpace,
    ) throws -> CGImage {
        guard metalTexture.pixelFormat == .bgra8Unorm else {
            throw CGImageFromMetalTextureError.unsupportedPixelFormat
        }

        let width = metalTexture.width
        let height = metalTexture.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let byteCount = bytesPerRow * height
        let region = MTLRegionMake2D(0, 0, width, height)

        var pixelData = Data(count: byteCount)
        pixelData.withUnsafeMutableBytes { buffer in
            guard let pointer = buffer.baseAddress else { return }
            metalTexture.getBytes(
                pointer,
                bytesPerRow: bytesPerRow,
                from: region,
                mipmapLevel: 0,
            )
        }

        guard let dataProvider = CGDataProvider(data: pixelData as CFData) else {
            throw CGImageFromMetalTextureError.failedToCreateDataProvider
        }

        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )

        guard
            let cgImage = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: dataProvider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent,
            )
        else {
            throw CGImageFromMetalTextureError.failedToCreateImage
        }

        return cgImage
    }
}
