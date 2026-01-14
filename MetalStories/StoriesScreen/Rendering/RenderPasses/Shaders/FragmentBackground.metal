#include "Common.h"

METAL_FUNC
float4 process_bg_color(float4 top, float4 bottom, float2 uv) {
    const auto color = mix(top, bottom, uv.y);
    return saturate(color);
}

fragment
float4 fragment_background(VertexOut in [[ stage_in ]],
                           constant float4& topColor [[ buffer(0) ]],
                           constant float4& bottomColor [[ buffer(1) ]]
                           ) {
    return process_bg_color(topColor, bottomColor, in.uv);
}

fragment
FragmentOut fragment_background_tile_memory(VertexOut in [[ stage_in ]],
                                            constant float4& topColor [[ buffer(0) ]],
                                            constant float4& bottomColor [[ buffer(1) ]]
                                            ) {
    FragmentOut out {
        .color = process_bg_color(topColor, bottomColor, in.uv)
    };
    return out;
}
