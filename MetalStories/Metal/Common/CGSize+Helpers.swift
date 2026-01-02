import CoreGraphics
import simd

// TODO: remove it
extension CGSize {
    var asFloat2: SIMD2<Float> {
        .init(Float(width), Float(height))
    }
}
