#include "Common.h"

// write meaningful comments and MARKs
// arrange code in the better order

// MARK: - Constants

/// Number of filter variants available
constant short kAvailableFiltersCount [[function_constant(0)]];

/// Total number of filters available
constant short kTotalFiltersCount = 9;

// MARK: - Color Space Matrices

constant float3x3 kLinearRgbToLms = float3x3(
    float3(0.4122214708f, 0.2119034982f, 0.0883024619f),
    float3(0.5363325363f, 0.6806995451f, 0.2817188376f),
    float3(0.0514459929f, 0.1073969566f, 0.6299787005f)
);
constant float3x3 kLmsToOklab = float3x3(
    float3(0.2104542553f, 1.9779984951f, 0.0259040371f),
    float3(0.7936177850f, -2.4285922050f, 0.7827717662f),
    float3(-0.0040720468f, 0.4505937099f, -0.8086757660f)
);
constant float3x3 kOklabToLms = float3x3(
    float3(1.0f, 1.0f, 1.0f),
    float3(0.3963377774f, -0.1055613458f, -0.0894841775f),
    float3(0.2158037573f, -0.0638541728f, -1.2914855480f)
);
constant float3x3 kLmsToLinearRgb = float3x3(
    float3(4.0767416621f, -1.2684380046f, -0.0041960863f),
    float3(-3.3077115913f, 2.6097574011f, -0.7034186147f),
    float3(0.2309699292f, -0.3413193965f, 1.7076147010f)
);

// MARK: - Utilities

/// Computes Rec. 709 luminance for a linear RGB color.
METAL_FUNC
float luminance(float3 rgb) {
    const auto kRec709Coeff = float3(0.2126f, 0.7152f, 0.0722f);
    return dot(kRec709Coeff, rgb);
}

// TODO: write comment
METAL_FUNC
float3 brightness(float3 rgb, float amount) {
    return rgb + amount;
}

// TODO: write comment
METAL_FUNC
float3 contrast(float3 rgb, float amount, float pivot) {
    return (rgb - pivot) * amount + pivot;
}

/// Photoshop-style channel mixer (output channel rows -> input channel columns).
METAL_FUNC
float3 channel_mixer(float3 rgb, float3 outR, float3 outG, float3 outB) {
    const auto matrix = float3x3(float3(outR.x, outG.x, outB.x),
                                 float3(outR.y, outG.y, outB.y),
                                 float3(outR.z, outG.z, outB.z));
    return matrix * rgb;
}

/// Bilinear interpolation of 4 corner colors based on UV coordinates.
/// Returns a smoothly blended color across the 2D surface.
METAL_FUNC
float3 gradient_2d(float3 bottomLeft,
                   float3 bottomRight,
                   float3 topLeft,
                   float3 topRight,
                   float2 uv) {
    const auto bottom = mix(bottomLeft, bottomRight, uv.x);
    const auto top = mix(topLeft, topRight, uv.x);
    return mix(bottom, top, uv.y);
}

// MARK: - Tone Curves

/// Evaluates a 5-point Catmull-Rom spline at `value`.
/// Control points are sampled at 0.0, 0.25, 0.5, 0.75, and 1.0.
METAL_FUNC
float catmull_rom_5_single(float p000,
                           float p025,
                           float p050,
                           float p075,
                           float p100,
                           float value) {
    const auto p_pre = 2.0f * p000 - p025;
    const auto p_post = 2.0f * p100 - p075;
    
    const auto t = saturate(value) * 4.0f;
    const auto segment = min(short(t), short(3));
    const auto t_res = t - float(segment);
    
    const float p[7] = { p_pre, p000, p025, p050, p075, p100, p_post };
    const auto idx = ushort(segment);
    const auto p0_res = p[idx];
    const auto p1_res = p[idx + 1];
    const auto p2_res = p[idx + 2];
    const auto p3_res = p[idx + 3];
    
    const auto t2 = t_res * t_res;
    const auto t3 = t2 * t_res;
    
    return 0.5f * (2.f * p1_res +
                   (p2_res - p0_res) * t_res +
                   (2.f * p0_res - 5.f * p1_res + 4.f * p2_res - p3_res) * t2 +
                   (-p0_res + 3.f * p1_res - 3.f * p2_res + p3_res) * t3);
}

/// Mild contrast curve for luma values.
METAL_FUNC
float toneCurveCatmullRom(float value) {
    return catmull_rom_5_single(0.f, 0.2f, 0.5f, 0.8f, 1.f, value);
}

/// Applies the 5-point Catmull-Rom spline to each RGB channel.
METAL_FUNC
float3 catmull_rom_5_rgb(float p000,
                         float p025,
                         float p050,
                         float p075,
                         float p100,
                         float3 rgb) {
    return float3(catmull_rom_5_single(p000, p025, p050, p075, p100, rgb.r),
                  catmull_rom_5_single(p000, p025, p050, p075, p100, rgb.g),
                  catmull_rom_5_single(p000, p025, p050, p075, p100, rgb.b));
}

// MARK: - Blend Modes

METAL_FUNC
float3 linear_light_blend(float3 source, float3 overlay, float a) {
    const auto linearLight = fma(overlay, 2.f, source - 1.f);
    return mix(source, saturate(linearLight), a);
}

// MARK: - Color Spaces

METAL_FUNC
float3 rgb_to_oklab(float3 rgb) {
    const auto lms = kLinearRgbToLms * rgb;
    const float kOneThird = 1.0f / 3.0f;
    const auto lms_cube_root = sign(lms) * pow(abs(lms), kOneThird);
    return kLmsToOklab * lms_cube_root;
}

METAL_FUNC
float3 oklab_to_rgb(float3 oklab) {
    const auto lms_cbrt = kOklabToLms * oklab;
    const auto lms = lms_cbrt * lms_cbrt * lms_cbrt;
    return kLmsToLinearRgb * lms;
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

    const auto contrastedLuma = catmull_rom_5_single(0.06f, 0.2f, 0.6f, 0.88f, 0.99f, luma);
    const auto mono = float3(contrastedLuma);

    // TODO: rebuild using another functions for masks
    const auto shadowMask = catmull_rom_5_single(1.0f, 0.9f, 0.4f, 0.1f, 0.0f, contrastedLuma);
    const auto highlightMask = catmull_rom_5_single(0.0f, 0.0f, 0.2f, 0.8f, 1.0f, contrastedLuma);
    const auto sheenMask = catmull_rom_5_single(0.0f, 0.0f, 0.15f, 0.85f, 1.0f, contrastedLuma);
    const auto midTonesMask = catmull_rom_5_single(0.0f, 0.7f, 1.0f, 0.4f, 0.0f, contrastedLuma);

    const auto shadowTint = float3(0.94f, 0.96f, 1.02f);
    const auto highlightTint = float3(0.98f, 1.01f, 1.06f);
    const auto sheenTint = float3(0.01f, 0.015f, 0.03f);

    auto graded = mono;
    graded = mix(graded, graded * shadowTint, shadowMask);
    graded = mix(graded, graded * highlightTint, highlightMask);
    graded = graded + sheenTint * sheenMask;

    return mix(graded, mono, midTonesMask * 0.2f);
}

/// Fire and ice: contrast curve with cool/warm channel separation. Inspired by orange and teal color grading
METAL_FUNC
float3 fire_and_ice(float3 rgb) {
    const auto contrastRGB = catmull_rom_5_rgb(0.f, 0.21f, 0.5f, 0.79f, 1.f, rgb);
    
    const auto filteredR = catmull_rom_5_single(0.f, 0.2f, 0.5f, 0.77f, 1.f, contrastRGB.r);
    const auto filteredG = catmull_rom_5_single(0.f, 0.26f, 0.5f, 0.74f, 1.f, contrastRGB.g);
    const auto filteredB = catmull_rom_5_single(0.f, 0.30f, 0.5f, 0.74f, 0.95f, contrastRGB.b);
    
    return float3(filteredR, filteredG, filteredB);
}

/// Perceptual vibrance: boosts low-chroma colors more than saturated ones.
METAL_FUNC
float3 chroma_vibrance(float3 rgb) {
    const auto lab = rgb_to_oklab(rgb);
    const auto chroma = length(lab.yz);
    const auto kChromaPivot = 0.45f;
    const auto kBaseBoost = 0.1f;
    const auto kExtraBoost = 0.45f;
    const auto boost = kBaseBoost + kExtraBoost * (1.0f - saturate(chroma / kChromaPivot));
    const auto ab = lab.yz * (1.f + boost);
    return oklab_to_rgb(float3(lab.x, ab));
}

/// Cross process: RGB matrix mix for highlights with opposite shadows.
METAL_FUNC
float3 cross_process(float3 rgb) {
    const auto contrastedRGB = catmull_rom_5_rgb(0.f, 0.2f, 0.5f, 0.8f, 1.f, rgb);

    const auto mixerOutR = float3(1.5f, -0.9f, 0.4f);
    const auto mixerOutG = float3(0.3f, 0.f, 0.7f);
    const auto mixerOutB = float3(0.f, 0.2f, 1.f);

    return channel_mixer(contrastedRGB, mixerOutR, mixerOutG, mixerOutB);
}

/// Bleach bypass: desaturated and high contrast. Based on NVIDIA implementation
/// https://developer.download.nvidia.com/shaderlibrary/webpages/screenshots/cgfx/post_bleach_bypass.html
METAL_FUNC
float3 bleach_bypass(float3 rgb) {
    
    const auto luma = luminance(rgb);
    const auto mask = saturate(10.f * (luma - 0.45f));
    
    const auto newColor = mix(2.f * rgb * luma,
                              1.f - 2.f * (1.f - luma) * (1.f - rgb),
                              mask);
    
    return mix(rgb, newColor, 0.8f);
}

/// Orange Sunset style: warm 2D gradient overlay with Linear Light Blend Mode
METAL_FUNC
float3 orange_sunset(float3 rgb, float2 uv) {
    const auto contrasted = catmull_rom_5_rgb(0.f, 0.22f, 0.5f, 0.78f, 1.f, rgb);
    const auto gradient = gradient_2d(float3(0.98f, 0.72f, 0.82f),
                                      float3(0.92f, 0.56f, 0.98f),
                                      float3(1.0f, 0.52f, 0.2f),
                                      float3(1.0f, 0.46f, 0.6f),
                                      uv);
    const auto blended = linear_light_blend(contrasted, gradient, 0.15f);
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
        case 5: targetColor = bleach_bypass(rgb); break; 
        case 6: targetColor = orange_sunset(rgb, uv); break;
        case 7: targetColor = chroma_vibrance(rgb); break;
        case 8: targetColor = cross_process(rgb); break;
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
