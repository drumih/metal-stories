import Metal
import simd

struct RenderPassInput {
    let imageTexture: MTLTexture
    let transform: float4x4
    let bottomBackgroundColor: SIMD4<Float>
    let topBackgroundColor: SIMD4<Float>
    let filterPositionOffset: Float
}
