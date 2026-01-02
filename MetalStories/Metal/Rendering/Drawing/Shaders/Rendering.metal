#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut vertex_general(uint vid [[vertex_id]],
                                constant float4x4& transform [[ buffer(0) ]]
                                ) {
    const auto index = vid % 4;
    float4 position;
    float2 uv;
    switch (index) {
        case 0: position = float4(-1.f, -1.f, 0.f, 1.f); uv = float2(0.f, 0.f); break;
        case 1: position = float4( 1.f, -1.f, 0.f, 1.f); uv = float2(1.f, 0.f); break;
        case 2: position = float4(-1.f,  1.f, 0.f, 1.f); uv = float2(0.f, 1.f); break;
        case 3: position = float4( 1.f,  1.f, 0.f, 1.f); uv = float2(1.f, 1.f); break;
    }

    VertexOut out {
        .position = transform * position,
        .uv = uv
    };
    return out;
}

fragment float4 fragment_image(VertexOut in [[stage_in]],
                               texture2d<float, access::sample> texture [[ texture(0) ]]
                               ) {
    constexpr sampler textureSampler(filter::linear,
                                     address::repeat);
    return texture.sample(textureSampler, in.uv);
}

fragment float4 fragment_background(VertexOut in [[ stage_in ]],
                                    constant float4& top_color [[ buffer(0) ]],
                                    constant float4& bottom_color [[ buffer(1) ]]
                                    ) {
    const auto background_color = mix(top_color, bottom_color, in.uv.y);
    return background_color;
}

METAL_FUNC float3 black_and_white(float3 rgb) {
    const auto rec_709_coeff = float3(0.2126f, 0.7152f, 0.0722f);
    const auto blackAndWhite = dot(rec_709_coeff, rgb);
    return saturate(blackAndWhite);
}

METAL_FUNC float3 filter_rgb(float3 rgb, short mode) {
    switch (mode) {
    case 0: return rgb;
    case 1: return black_and_white(rgb);
    default: return rgb;
    }
}

constant float filterCountF = 2.f;
fragment float4 fragment_post_processing(VertexOut in [[ stage_in ]],
                                         texture2d<float, access::sample> texture [[ texture(0) ]],
                                         constant float& offset [[ buffer(0) ]]
                                        ) {
    constexpr sampler textureSampler(filter::linear,
                                     address::repeat);
    const auto color = texture.sample(textureSampler, in.uv);

    // TODO: refactor this piece of code a bit
    const auto wrapped = offset - filterCountF * floor(offset / filterCountF);
    const auto mode = short(floor(wrapped));
    const auto next_mode = (mode + 1) % short(filterCountF);
    const auto target_mode = in.uv.x > fract(wrapped) ? mode : next_mode;
    const auto filtered_color = filter_rgb(color.rgb, target_mode);

    return float4(saturate(filtered_color), color.a);
}
