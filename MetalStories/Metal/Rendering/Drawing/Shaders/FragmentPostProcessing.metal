#include "Common.h"

METAL_FUNC float3 black_and_white(float3 rgb) {
    const auto rec_709_coeff = float3(0.2126f, 0.7152f, 0.0722f);
    const auto blackAndWhite = dot(rec_709_coeff, rgb);
    return saturate(blackAndWhite);
}

METAL_FUNC float3 process_rgb(float3 rgb, float2 uv, float offset) {
    // TODO: refactor this piece of code a bit
    constexpr float filterCountF = 2.f;
    const auto wrapped = offset - filterCountF * floor(offset / filterCountF);
    const auto mode = short(floor(wrapped));
    const auto next_mode = (mode + 1) % short(filterCountF);
    const auto target_mode = uv.x > fract(wrapped) ? mode : next_mode;

    float3 target_color;

    switch (target_mode) {
        case 0: target_color = rgb; break;
        case 1: target_color = black_and_white(rgb); break;
        default: target_color = rgb; break;
    }
    
    return saturate(target_color);
}

fragment float4 fragment_post_processing(VertexOut in [[ stage_in ]],
                                         texture2d<float, access::sample> texture [[ texture(0) ]],
                                         constant float& offset [[ buffer(0) ]]
                                        ) {
    // TODO: use better sampler
    constexpr sampler textureSampler(filter::linear,
                                     address::repeat);
    const auto color = texture.sample(textureSampler, in.uv);
    const auto processed_rgb = process_rgb(color.rgb, in.uv, offset);
    return float4(processed_rgb, color.a);
}
