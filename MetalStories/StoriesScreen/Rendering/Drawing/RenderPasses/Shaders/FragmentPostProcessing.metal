#include "Common.h"

constant short kFiltersCount = 2;

// MARK: filters

METAL_FUNC
float3 black_and_white(float3 rgb) {
    constexpr float3 kRec709Coeff = float3(0.2126f, 0.7152f, 0.0722f);
    const auto blackAndWhite = dot(kRec709Coeff, rgb);
    return saturate(blackAndWhite);
}

// TODO: implement sepia filter
// TODO: implement instagram Paris filter
// TODO: implement instagram Fade Cold filter
// TODO: implement Instagram Fade Warm filter


// MARK: filter selection

METAL_FUNC
float3 process_rgb(float3 rgb, float2 uv, float offset) {
    const float filtersCount = float(kFiltersCount);
    const float normalizedOffset = offset - filtersCount * floor(offset / filtersCount);
    const short currentMode = short(normalizedOffset);
    const float splitPoint = normalizedOffset - float(currentMode);
    const short nextMode = (currentMode + 1) % kFiltersCount;
    const short targetMode = uv.x > splitPoint ? currentMode : nextMode;
    
    float3 targetColor;
    
    switch (targetMode) {
        case 0: targetColor = rgb; break;
        case 1: targetColor = black_and_white(rgb); break;
        default: targetColor = rgb; break;
    }
    
    return saturate(targetColor);
}

// MARK: fragment shaders

fragment
float4 fragment_post_processing(VertexOut in [[ stage_in ]],
                                texture2d<float, access::sample> texture [[ texture(0) ]],
                                constant float& offset [[ buffer(0) ]]
                                ) {
    constexpr sampler textureSampler(filter::linear,
                                     address::repeat);
    const auto color = texture.sample(textureSampler, in.uv);
    const auto processedRGB = process_rgb(color.rgb, in.uv, offset);
    return float4(processedRGB, color.a);
}

fragment
float4 fragment_post_processing_tile_memory(VertexOut vertexIn [[ stage_in ]],
                                            FragmentOut fragmentIn,
                                            constant float& offset [[ buffer(0) ]]
                                            ) {
    const auto color = fragmentIn.color;
    const auto processedRGB = process_rgb(color.rgb, vertexIn.uv, offset);
    
    return float4(processedRGB, color.a);
}
