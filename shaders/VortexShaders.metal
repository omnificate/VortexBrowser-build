#include <metal_stdlib>
#include <simd/simd.h>
using namespace metal;

// Vertex structure
struct VertexIn {
    float2 position [[attribute(0)]];
    float2 tex_coord [[attribute(1)]];
    float4 color [[attribute(2)]];
    float z [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 tex_coord;
    float4 color;
    float z;
};

// Uniform structure
struct Uniforms {
    float4x4 transform;
    float4 clip_rect;
    float2 viewport_size;
    float time;
};

// Vertex shader - main rendering
vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                            constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    
    // Transform position
    float4 pos = float4(in.position, in.z, 1.0);
    out.position = uniforms.transform * pos;
    
    // Convert to normalized device coordinates
    out.position.x = (out.position.x / uniforms.viewport_size.x) * 2.0 - 1.0;
    out.position.y = -((out.position.y / uniforms.viewport_size.y) * 2.0 - 1.0);
    
    out.tex_coord = in.tex_coord;
    out.color = in.color;
    out.z = in.z;
    
    return out;
}

// Fragment shader - solid color
fragment float4 fragment_color(VertexOut in [[stage_in]]) {
    return in.color;
}

// Fragment shader - textured
fragment float4 fragment_texture(VertexOut in [[stage_in]],
                                texture2d<float> texture [[texture(0)]],
                                sampler texture_sampler [[sampler(0)]]) {
    return texture.sample(texture_sampler, in.tex_coord) * in.color;
}

// Fragment shader - SDF text rendering
fragment float4 fragment_text_sdf(VertexOut in [[stage_in]],
                                  texture2d<float> sdf_atlas [[texture(0)]],
                                  sampler sdf_sampler [[sampler(0)]]) {
    float distance = sdf_atlas.sample(sdf_sampler, in.tex_coord).r;
    
    // Smoothstep for anti-aliased edges
    float alpha = smoothstep(0.5 - 0.05, 0.5 + 0.05, distance);
    
    return float4(in.color.rgb, in.color.a * alpha);
}

// Fragment shader - rounded rectangle with shadow
fragment float4 fragment_rounded_rect(VertexOut in [[stage_in]],
                                    constant float4& rect_params [[buffer(2)]]) {
    float2 center = rect_params.xy;
    float2 half_size = rect_params.zw;
    float radius = rect_params.w;
    
    float2 pos = in.tex_coord * half_size * 2.0;
    float2 dist = abs(pos - center) - half_size + radius;
    float sdf = length(max(dist, 0.0)) - radius;
    
    float alpha = 1.0 - smoothstep(0.0, 1.0, sdf);
    
    return float4(in.color.rgb, in.color.a * alpha);
}

// Fragment shader - gradient background
fragment float4 fragment_gradient(VertexOut in [[stage_in]],
                                constant float4& color1 [[buffer(2)]],
                                constant float4& color2 [[buffer(3)]],
                                constant float& angle [[buffer(4)]]) {
    float t = (in.tex_coord.x * cos(angle) + in.tex_coord.y * sin(angle)) * 0.5 + 0.5;
    return mix(color1, color2, t) * in.color;
}

// Compute shader - Flexbox layout calculation
kernel void flex_layout_compute(device float4* items [[buffer(0)]],
                                device float2* results [[buffer(1)]],
                                constant float& container_width [[buffer(2)]],
                                constant uint& item_count [[buffer(3)]],
                                uint id [[thread_position_in_grid]]) {
    if (id >= item_count) return;
    
    float4 item = items[id];
    float flex_grow = item.z;
    float flex_basis = item.w;
    
    // Simplified flex calculation
    float position = id * (container_width / float(item_count));
    float size = flex_basis;
    
    if (flex_grow > 0) {
        float extra_space = (container_width - (flex_basis * float(item_count))) / float(item_count);
        size += extra_space * flex_grow;
    }
    
    results[id] = float2(position, size);
}

// Compute shader - Text glyph positioning
kernel void text_shaping_compute(device uint* codepoints [[buffer(0)]],
                                  device float2* positions [[buffer(1)]],
                                  device float2* advances [[buffer(2)]],
                                  constant float& font_size [[buffer(3)]],
                                  constant float& line_width [[buffer(4)]],
                                  constant uint& glyph_count [[buffer(5)]],
                                  uint id [[thread_position_in_grid]]) {
    if (id >= glyph_count) return;
    
    // Simple shaping - advance based on previous glyph
    float x = 0.0;
    float y = 0.0;
    
    for (uint i = 0; i <= id; i++) {
        float advance = advances[i].x * font_size;
        
        if (x + advance > line_width && i > 0) {
            x = 0.0;
            y += font_size * 1.2; // line height
        }
        
        if (i == id) {
            positions[id] = float2(x, y);
        }
        
        x += advance;
    }
}

// Compute shader - Layer culling
kernel void cull_layers_compute(device float4* layer_bounds [[buffer(0)]],
                                 device uint* visibility [[buffer(1)]],
                                 constant float4& view_rect [[buffer(2)]],
                                 constant uint& layer_count [[buffer(3)]],
                                 uint id [[thread_position_in_grid]]) {
    if (id >= layer_count) return;
    
    float4 bounds = layer_bounds[id];
    float4 view = view_rect;
    
    // AABB intersection test
    bool visible = !(bounds.x > view.x + view.z ||
                     bounds.x + bounds.z < view.x ||
                     bounds.y > view.y + view.w ||
                     bounds.y + bounds.w < view.y);
    
    visibility[id] = visible ? 1 : 0;
}

// Fragment shader - Blur effect (two-pass)
kernel void blur_horizontal(texture2d<float, access::read> in_texture [[texture(0)]],
                           texture2d<float, access::write> out_texture [[texture(1)]],
                           constant float* kernel [[buffer(0)]],
                           constant int& kernel_radius [[buffer(1)]],
                           uint2 gid [[thread_position_in_grid]]) {
    float4 sum = float4(0.0);
    int width = in_texture.get_width();
    
    for (int i = -kernel_radius; i <= kernel_radius; i++) {
        int x = clamp(int(gid.x) + i, 0, width - 1);
        sum += in_texture.read(uint2(x, gid.y)) * kernel[i + kernel_radius];
    }
    
    out_texture.write(sum, gid);
}

kernel void blur_vertical(texture2d<float, access::read> in_texture [[texture(0)]],
                         texture2d<float, access::write> out_texture [[texture(1)]],
                         constant float* kernel [[buffer(0)]],
                         constant int& kernel_radius [[buffer(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    float4 sum = float4(0.0);
    int height = in_texture.get_height();
    
    for (int i = -kernel_radius; i <= kernel_radius; i++) {
        int y = clamp(int(gid.y) + i, 0, height - 1);
        sum += in_texture.read(uint2(gid.x, y)) * kernel[i + kernel_radius];
    }
    
    out_texture.write(sum, gid);
}

// Fragment shader - Color matrix filter
fragment float4 fragment_color_matrix(VertexOut in [[stage_in]],
                                     texture2d<float> source [[texture(0)]],
                                     sampler source_sampler [[sampler(0)]],
                                     constant float4x4& matrix [[buffer(2)]]) {
    float4 color = source.sample(source_sampler, in.tex_coord);
    return matrix * color;
}

// Vertex shader - tile-based instanced rendering
struct InstanceData {
    float4 rect;
    float4 color;
    float4 tex_coords;
    uint texture_id;
};

vertex VertexOut vertex_instanced(VertexIn in [[stage_in]],
                                  constant InstanceData* instances [[buffer(2)]],
                                  constant Uniforms& uniforms [[buffer(1)]],
                                  uint instance_id [[instance_id]]) {
    InstanceData instance = instances[instance_id];
    
    VertexOut out;
    
    // Scale and position
    float2 pos = in.position * instance.rect.zw + instance.rect.xy;
    
    float4 world_pos = float4(pos, 0.0, 1.0);
    out.position = uniforms.transform * world_pos;
    
    // NDC conversion
    out.position.x = (out.position.x / uniforms.viewport_size.x) * 2.0 - 1.0;
    out.position.y = -((out.position.y / uniforms.viewport_size.y) * 2.0 - 1.0);
    
    // Interpolate tex coords
    out.tex_coord = in.tex_coord * instance.tex_coords.zw + instance.tex_coords.xy;
    out.color = instance.color;
    
    return out;
}
