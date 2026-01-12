#include "Common.h"

constant short kFiltersCount = 3;

// MARK: adjustments

// TODO: write func documentation. explain what it does
METAL_FUNC
float luminance(float3 rgb) {
    const float3 kRec709Coeff = float3(0.2126f, 0.7152f, 0.0722f);
    return dot(kRec709Coeff, rgb);
}

// TODO: write func documentation. explain what it does
METAL_FUNC
float3 adjust_brightness(float3 rgb, float value) {
    return rgb + value;
}

// TODO: write func documentation. value from 0.5 to 1.5. explain what it does. pivot in 0..1
METAL_FUNC
float3 adjust_contrast(float3 rgb, float value, float pivot) {
    return (rgb - pivot) * value + pivot;
}

// TODO: write func documentation.
METAL_FUNC
float2 catmull_rom_segment(float2 p0, float2 p1, float2 p2, float2 p3, float t)
{
    const auto t2 = t * t;
    const auto t3 = t2 * t;

    return 0.5f * (
        2.f * p1 +
        (p2 - p0) * t +
        (2.f * p0 - 5.f * p1 + 4.f * p2 - p3) * t2 +
        (-p0 + 3.f * p1 - 3.f * p2 + p3) * t3
    );
}

// TODO: write func documentation.
METAL_FUNC
float2 catmull_rom_5(float2 p0, float2 p1, float2 p2, float2 p3, float2 p4, float value) {
    // With 5 points we have 4 segments: p0→p1, p1→p2, p2→p3, p3→p4
    // Each segment spans 0.25 of the value range
    
    // For boundary segments, extend control points by reflection
    const float2 p_pre = 2.0f * p0 - p1;   // virtual point before p0
    const float2 p_post = 2.0f * p4 - p3;  // virtual point after p4
    
    const float t = saturate(value) * 4.0f;
    const short segment = min(short(t), short(3));
    const float local_t = t - float(segment);
    
    switch (segment) {
        case 0: return catmull_rom_segment(p_pre, p0, p1, p2, local_t);
        case 1: return catmull_rom_segment(p0, p1, p2, p3, local_t);
        case 2: return catmull_rom_segment(p1, p2, p3, p4, local_t);
        case 3: return catmull_rom_segment(p2, p3, p4, p_post, local_t);
        default: return p4;
    }
}

// MARK: filters


METAL_FUNC
float3 dramatic_bw(float3 rgb) {
    const auto lum = luminance(rgb);
    const auto bw = float3(lum);
    const auto dramaticBW = adjust_contrast(bw, 1.3, 0.4);
    return saturate(dramaticBW);
}

METAL_FUNC
float3 fire_and_ice(float3 rgb) {
    const auto filteredR = catmull_rom_5(float2(0.f, 0.f),
                                         float2(0.25f, 0.22f),
                                         float2(0.5f, 0.5f),
                                         float2(0.75f, 0.78f),
                                         float2(1.f, 1.f),
                                         rgb.r);
    const auto filteredG = catmull_rom_5(float2(0.f, 0.f),
                                         float2(0.25f, 0.21f),
                                         float2(0.5f, 0.5f),
                                         float2(0.75f, 0.79f),
                                         float2(1.f, 1.f),
                                         rgb.g);
    const auto filteredB = catmull_rom_5(float2(0.f, 0.f),
                                         float2(0.25f, 0.3f),
                                         float2(0.5f, 0.48f),
                                         float2(0.75f, 0.7f),
                                         float2(1.f, 1.f),
                                         rgb.b);

    // TODO: add more contrast
    return float3(filteredR.y, filteredG.y, filteredB.y);
    
}

// TODO: implement sepia filter
// TODO: implement instagram Paris filter
// TODO: implement instagram Fade Cold filter
// TODO: implement Instagram Fade Warm filter


// MARK: filter selection

METAL_FUNC
short target_mode(float2 uv, float offset) {
    const auto filtersCount = float(kFiltersCount);
    const auto normalizedOffset = offset - filtersCount * floor(offset / filtersCount);
    const auto currentMode = short(normalizedOffset);
    const auto splitPoint = normalizedOffset - float(currentMode);
    const auto nextMode = (currentMode + 1) % kFiltersCount;
    const auto targetMode = uv.x > splitPoint ? currentMode : nextMode;
    return targetMode;
}

METAL_FUNC
float3 process_rgb(float3 rgb, float2 uv, float offset) {
    const auto targetMode = target_mode(uv, offset);
    float3 targetColor;
    switch (targetMode) {
        case 0: targetColor = rgb; break;
        case 1: targetColor = dramatic_bw(rgb); break;
        case 2: targetColor = fire_and_ice(rgb); break;
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
