#ifndef Common_h
#define Common_h

#include <metal_stdlib>
using namespace metal;


// MARK: - Vertex Out
struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

// MARK: - Fragment Out

struct FragmentOut {
    float4 color [[color(1)]];
};

#endif // !Common_h
