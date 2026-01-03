#include "Common.h"

fragment
float4 fragment_background(VertexOut in [[ stage_in ]],
                           constant float4& top_color [[ buffer(0) ]],
                           constant float4& bottom_color [[ buffer(1) ]]
                                    ) {
    // TODO: use dithering
    const auto background_color = mix(top_color, bottom_color, in.uv.y);
    return background_color;
}
