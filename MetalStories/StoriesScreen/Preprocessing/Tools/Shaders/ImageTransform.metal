#include <metal_stdlib>
using namespace metal;

kernel
void imageTransform(
                    texture2d<float, access::sample> source [[texture(0)]],
                    texture2d<float, access::write> destination [[texture(1)]],
                    constant float4x4& uvTransform [[buffer(0)]],
                    ushort2 position [[thread_position_in_grid]]
                    ) {
    const auto targetTextureSize = ushort2(destination.get_width(), destination.get_height());
    if (position.x >= targetTextureSize.x || position.y >= targetTextureSize.y) {
        return;
    }
    constexpr sampler textureSampler(filter::bicubic, address::clamp_to_edge);
    const auto uv = (float2(position) + 0.5f) / float2(targetTextureSize);
    const auto targetUV = uvTransform * float4(uv, 0.f, 1.f);
    const auto resultColor = source.sample(textureSampler, targetUV.xy);
    destination.write(resultColor, position);
}
