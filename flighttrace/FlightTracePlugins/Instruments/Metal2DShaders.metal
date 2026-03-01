// Metal2DShaders.metal
// Basic 2D shaders for instrument rendering

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 uv [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

struct ViewportUniforms {
    float2 viewportSize;
};

struct ColorUniforms {
    float4 color;
};

vertex VertexOut vertex_passthrough(
    VertexIn in [[stage_in]],
    constant ViewportUniforms &viewport [[buffer(1)]]
) {
    VertexOut out;
    float2 ndc;
    ndc.x = (in.position.x / viewport.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (in.position.y / viewport.viewportSize.y) * 2.0;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = in.uv;
    return out;
}

fragment float4 fragment_solid(
    VertexOut in [[stage_in]],
    constant ColorUniforms &color [[buffer(2)]]
) {
    return color.color;
}

fragment float4 fragment_textured(
    VertexOut in [[stage_in]],
    texture2d<float> tex [[texture(0)]],
    sampler samp [[sampler(0)]],
    constant ColorUniforms &color [[buffer(2)]]
) {
    float4 sampleColor = tex.sample(samp, in.uv);
    return sampleColor * color.color;
}
