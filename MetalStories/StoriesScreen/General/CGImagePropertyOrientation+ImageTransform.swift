import ImageIO
import simd

extension CGImagePropertyOrientation {

    struct ImageTransformParams {
        let rotationRadians: Float
        let swapsDimensions: Bool
        let isMirrored: Bool
    }

    func imageTransformParams() -> ImageTransformParams {
        switch self {
        case .up:
            .init(
                rotationRadians: 0,
                swapsDimensions: false,
                isMirrored: false,
            )

        case .upMirrored:
            .init(
                rotationRadians: 0,
                swapsDimensions: false,
                isMirrored: true,
            )

        case .right:
            .init(
                rotationRadians: -.pi / 2,
                swapsDimensions: true,
                isMirrored: false,
            )

        case .rightMirrored:
            .init(
                rotationRadians: -.pi / 2,
                swapsDimensions: true,
                isMirrored: true,
            )

        case .down:
            .init(
                rotationRadians: .pi,
                swapsDimensions: false,
                isMirrored: false,
            )

        case .downMirrored:
            .init(
                rotationRadians: .pi,
                swapsDimensions: false,
                isMirrored: true,
            )

        case .left:
            .init(
                rotationRadians: .pi / 2,
                swapsDimensions: true,
                isMirrored: false,
            )

        case .leftMirrored:
            .init(
                rotationRadians: .pi / 2,
                swapsDimensions: true,
                isMirrored: true,
            )

        @unknown default:
            .init(
                rotationRadians: 0,
                swapsDimensions: false,
                isMirrored: false,
            )
        }
    }
}
