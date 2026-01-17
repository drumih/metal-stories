#include "Common.h"

// MARK: - Constants

/// Number of filter variants available in `process_rgb`.
constant short kAvailableFiltersCount [[function_constant(0)]];

constant short kTotalFiltersCount = 9;

// MARK: - Utilities

/// Computes Rec. 709 luminance for a linear RGB color.
METAL_FUNC
float luminance(float3 rgb) {
    const float3 kRec709Coeff = float3(0.2126f, 0.7152f, 0.0722f);
    return dot(kRec709Coeff, rgb);
}

METAL_FUNC
float3 brightness(float3 rgb, float amount) {
    return rgb + amount;
}

METAL_FUNC
float3 contrast(float3 rgb, float amount, float pivot) {
    return (rgb - pivot) * amount + pivot;
}

/// Applies a 3x3 channel mixing matrix (column-major).
/// Each column defines the contribution of the input R/G/B to the output RGB.
METAL_FUNC
float3 apply_channel_matrix(float3 rgb, float3x3 matrix) {
    return matrix * rgb;
}

/// Applies split toning with separate tints for shadows and highlights.
/// `shadowTint` and `highlightTint` are multiplicative (1 = no change).
METAL_FUNC
float3 apply_split_tone(float3 rgb, float3 shadowTint, float3 highlightTint) {
    const float luma = luminance(rgb);
    const float shadowW = 1.0f - smoothstep(0.2f, 0.4f, luma);
    const float highlightW = smoothstep(0.6f, 0.8f, luma);
    
    float3 graded = mix(rgb, rgb * shadowTint, shadowW);
    graded = mix(graded, graded * highlightTint, highlightW);
    return graded;
}

/// Bilinear interpolation of 4 corner colors based on UV coordinates.
/// Returns a smoothly blended color across the 2D surface.
METAL_FUNC
float3 gradient_2d(float3 bottomLeft, float3 bottomRight, float3 topLeft, float3 topRight, float2 uv) {
    const float3 bottom = mix(bottomLeft, bottomRight, uv.x);
    const float3 top = mix(topLeft, topRight, uv.x);
    return mix(bottom, top, uv.y);
}

// MARK: - Tone Curves

/// Evaluates a 5-point Catmull-Rom spline at `value`.
/// Control points are sampled at 0.0, 0.25, 0.5, 0.75, and 1.0.
METAL_FUNC
float catmull_rom_5_single(float p000, float p025, float p050, float p075, float p100, float value) {
    const auto p_pre = 2.0f * p000 - p025;
    const auto p_post = 2.0f * p100 - p075;
    
    const auto t = saturate(value) * 4.0f;
    const auto segment = min(short(t), short(3));
    const auto t_res = t - float(segment);
    
    float p0_res; float p1_res; float p2_res; float p3_res;
    
    switch (segment) {
        case 0: p0_res = p_pre; p1_res = p000; p2_res = p025; p3_res = p050; break;
        case 1: p0_res = p000; p1_res = p025; p2_res = p050; p3_res = p075; break;
        case 2: p0_res = p025; p1_res = p050; p2_res = p075; p3_res = p100; break;
        case 3: p0_res = p050; p1_res = p075; p2_res = p100; p3_res = p_post; break;
        default: return p100;
    }
    
    const auto t2 = t_res * t_res;
    const auto t3 = t2 * t_res;
    
    return 0.5f * (
                   2.f * p1_res +
                   (p2_res - p0_res) * t_res +
                   (2.f * p0_res - 5.f * p1_res + 4.f * p2_res - p3_res) * t2 +
                   (-p0_res + 3.f * p1_res - 3.f * p2_res + p3_res) * t3
                   );
}

/// Applies the 5-point Catmull-Rom spline to each RGB channel.
METAL_FUNC
float3 catmull_rom_5_rgb(float p000, float p025, float p050, float p075, float p100, float3 rgb) {
    return float3(
                  catmull_rom_5_single(p000, p025, p050, p075, p100, rgb.r),
                  catmull_rom_5_single(p000, p025, p050, p075, p100, rgb.g),
                  catmull_rom_5_single(p000, p025, p050, p075, p100, rgb.b)
                  );
}

// MARK: - Blend Modes

METAL_FUNC
float3 linear_light_blend(float3 source, float3 overlay, float a) {
    const auto linearLight = fma(overlay, 2.f, source - 1.f);
    return mix(source, saturate(linearLight), a);
}

// MARK: - Filters

METAL_FUNC
float3 very_simple(float3 rgb) {
    const auto brighten = brightness(rgb, -0.1f);
    const auto contrasted = contrast(brighten, 1.3f, 0.5f);
    return contrasted;
}

/// Classic sepia look with a gentle contrast curve.
METAL_FUNC
float3 sepia(float3 rgb) {
    const auto luma = luminance(rgb);
    const auto contrasted = catmull_rom_5_single(0.f, 0.2f, 0.5f, 0.8f, 1.f, luma);
    const auto sepiaTint = float3(1.f, 0.92f, 0.78f);
    return contrasted * sepiaTint;
}

/// Noir chrome: high-contrast monochrome with cool highlights.
METAL_FUNC
float3 noir_chrome(float3 rgb) {
    const auto luma = luminance(rgb);
    const auto bw = catmull_rom_5_single(0.1f, 0.2f, 0.7f, 0.8f, 0.9f, luma);
    const auto toned = apply_split_tone(float3(bw),
                                        float3(0.9f, 0.95f, 1.1f),
                                        float3(1.02f, 1.0f, 0.98f));
    return toned;
}

/// Fire and ice: high-contrast curve with cool/warm channel separation.
METAL_FUNC
float3 fire_and_ice(float3 rgb) {
    const auto contrastRGB = catmull_rom_5_rgb(0.f, 0.22f, 0.5f, 0.78f, 1.f, rgb);
    
    const auto filteredR = catmull_rom_5_single(0.f, 0.22f, 0.5f, 0.78f, 1.f, contrastRGB.r);
    const auto filteredG = catmull_rom_5_single(0.f, 0.21f, 0.5f, 0.79f, 1.f, contrastRGB.g);
    const auto filteredB = catmull_rom_5_single(0.f, 0.3f, 0.48f, 0.7f, 1.f, contrastRGB.b);
    
    return float3(filteredR, filteredG, filteredB);
}

/// Cinematic teal/orange grade with highlight/shadow pushes and saturation.
METAL_FUNC
float3 teal_orange_cinema(float3 rgb) {
    // TODO: update it as well!
    const auto curved = catmull_rom_5_rgb(0.f, 0.18f, 0.52f, 0.85f, 1.f, rgb);
    return apply_split_tone(curved,
                            float3(0.9f, 0.98f, 1.08f),
                            float3(1.08f, 1.02f, 0.95f));
}

/// Cross-processed film look: contrast curve, channel mixing, and warmth.
METAL_FUNC
float3 cross_process(float3 rgb) {
    // TODO: do better and more clear!
    const auto contrastRGB = catmull_rom_5_rgb(0.f, 0.2f, 0.5f, 0.8f, 1.f, rgb);
    
    const float3 rowR = float3(1.1f, 0.05f, -0.08f);
    const float3 rowG = float3(-0.03f, 1.08f, 0.1f);
    const float3 rowB = float3(0.05f, -0.05f, 1.08f);
    const float3x3 crossProcessMatrix = float3x3(
                                                 float3(rowR.x, rowG.x, rowB.x),
                                                 float3(rowR.y, rowG.y, rowB.y),
                                                 float3(rowR.z, rowG.z, rowB.z)
                                                 );
    
    const auto mixed = apply_channel_matrix(contrastRGB, crossProcessMatrix);
    
    return mixed;
}

/// Bleach bypass: // TODO: write description

// TODO: redo
METAL_FUNC
float3 bleach_bypass(float3 rgb) {
    
    const float lum = luminance(rgb);
    const auto blend = float3(lum);
    const auto mask = saturate(10.0f * (lum - 0.45f));
    
    const auto result1 = 2.0f * rgb * blend;
    const auto result2 = 1.0f - 2.0f * (1.0f - blend) * (1.0f - rgb);
    const auto newColor = mix(result1, result2, mask);
    
    return mix(rgb, newColor, 0.8);
}

/// Orange Sunset style: warm 2D gradient overlay with Linear Light Blend Mode
METAL_FUNC
float3 orange_sunset(float3 rgb, float2 uv) {
    const auto curved = catmull_rom_5_rgb(0.f, 0.22f, 0.5f, 0.78f, 1.f, rgb);
    
    const auto topLeft = float3(1.0f, 0.52f, 0.2f);
    const auto topRight = float3(1.0f, 0.46f, 0.6f);
    const auto bottomLeft = float3(0.98f, 0.72f, 0.82f);
    const auto bottomRight = float3(0.92f, 0.56f, 0.98f);
    
    const auto gradient = gradient_2d(bottomLeft, bottomRight, topLeft, topRight, uv);
    
    const auto blended = linear_light_blend(curved, gradient, 0.15f);
    return blended;
}

// MARK: - Filter Selection

/// Selects the active filter index for a horizontal swipe transition.
/// `offset` is a fractional filter position: integer part is current filter,
/// fractional part defines the split position along `uv.x`.
METAL_FUNC
short target_mode(float2 uv, float offset) {
    const auto filtersCount = clamp(kAvailableFiltersCount, short(1), kTotalFiltersCount);
    const auto filtersCountF = float(filtersCount);
    
    const auto normalizedOffset = offset - filtersCountF * floor(offset / filtersCountF);
    const auto currentMode = short(normalizedOffset);
    const auto fraction = normalizedOffset - float(currentMode);
    
    const auto nextMode = (currentMode + 1) % filtersCount;
    
    const auto splitPoint = 1.f - fraction;
    return uv.x >= splitPoint ? nextMode : currentMode;
}

/// Applies the selected filter and clamps the result to [0, 1].
METAL_FUNC
float3 process_rgb(float3 rgb, float2 uv, float offset) {
    const auto targetMode = target_mode(uv, offset);
    float3 targetColor;
    switch (targetMode) {
        case 0: targetColor = rgb; break;
        case 1: targetColor = very_simple(rgb); break;
        case 2: targetColor = sepia(rgb); break;
        case 3: targetColor = noir_chrome(rgb); break;
        case 4: targetColor = fire_and_ice(rgb); break;
        case 5: targetColor = teal_orange_cinema(rgb); break;
        case 6: targetColor = cross_process(rgb); break;
        case 7: targetColor = bleach_bypass(rgb); break;
        case 8: targetColor = orange_sunset(rgb, uv); break;
        default: targetColor = rgb; break;
    }
    
    return saturate(targetColor);
}


// MARK: - Fragment Shaders

/// Post-processing path for regular texture sampling.
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

/// Post-processing path for tile memory render targets.
fragment
float4 fragment_post_processing_tile_memory(VertexOut vertexIn [[ stage_in ]],
                                            FragmentOut fragmentIn,
                                            constant float& offset [[ buffer(0) ]]
                                            ) {
    const auto color = fragmentIn.color;
    const auto processedRGB = process_rgb(color.rgb, vertexIn.uv, offset);
    return float4(processedRGB, color.a);
}

/// Post-processing path when tile memory color is provided via color attachment.
fragment
float4 fragment_post_processing_tile_memory_direct(VertexOut vertexIn [[ stage_in ]],
                                                   float4 colorIn [[color(0)]],
                                                   constant float& offset [[ buffer(0) ]]
                                                   ) {
    const auto processedRGB = process_rgb(colorIn.rgb, vertexIn.uv, offset);
    return float4(processedRGB, colorIn.a);
}
