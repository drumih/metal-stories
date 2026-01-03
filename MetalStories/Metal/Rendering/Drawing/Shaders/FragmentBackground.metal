#include "Common.h"

METAL_FUNC float4 process_bg_color(float4 top, float4 bottom, float2 uv) {
    // TODO: use dithering
    return saturate(mix(top, bottom, uv.y));
}

fragment
float4 fragment_background(VertexOut in [[ stage_in ]],
                           constant float4& top_color [[ buffer(0) ]],
                           constant float4& bottom_color [[ buffer(1) ]]
                           ) {
    return process_bg_color(top_color, bottom_color, in.uv);
}

fragment
FragmentOut fragment_background_tiled(VertexOut in [[ stage_in ]],
                                      constant float4& top_color [[ buffer(0) ]],
                                      constant float4& bottom_color [[ buffer(1) ]]
                                      ) {
    FragmentOut out {
        .color = process_bg_color(top_color, bottom_color, in.uv)
    };
    return out;
}
