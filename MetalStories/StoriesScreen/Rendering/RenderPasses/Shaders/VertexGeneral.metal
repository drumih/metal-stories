#include "Common.h"

vertex
VertexOut vertex_general(uint vid [[vertex_id]],
                         constant float4x4& mvpTransform [[ buffer(0) ]]
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
        .position = mvpTransform * position,
        .uv = uv
    };
    return out;
}
