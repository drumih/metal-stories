import CoreGraphics
import simd

extension CGSize {
    var asFloat2: SIMD2<Float> {
        .init(Float(width), Float(height))
    }
}
