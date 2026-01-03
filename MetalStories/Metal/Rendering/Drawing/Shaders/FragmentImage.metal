#include "Common.h"

fragment
float4 fragment_image(VertexOut in [[stage_in]],
                      texture2d<float, access::sample> texture [[ texture(0) ]]
                      ) {
    // TODO: use better sampler
    constexpr sampler textureSampler(filter::linear,
                                     address::repeat);
    return texture.sample(textureSampler, in.uv);
}

fragment
FragmentOut fragment_image_tiled(VertexOut in [[stage_in]],
                                 texture2d<float, access::sample> texture [[ texture(0) ]]
                                 ) {
    constexpr sampler textureSampler(filter::linear,
                                     address::repeat);
    FragmentOut out {
        .color = texture.sample(textureSampler, in.uv)
    };
    return out;
}
