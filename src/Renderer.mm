#include "vortex/Renderer.h"
#include "vortex/Core.h"

#include <Metal/Metal.h>
#include <QuartzCore/QuartzCore.h>
#include <simd/simd.h>

namespace Vortex {
namespace Render {

// Metal shader source code
static const char* vertexShaderSource = R"(
#include <metal_stdlib>
using namespace metal;

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
};

struct Uniforms {
    float4x4 transform;
    float4 clip_rect;
};

vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant Uniforms& uniforms [[buffer(1)]]) {
    VertexOut out;
    float4 pos = float4(in.position, in.z, 1.0);
    out.position = uniforms.transform * pos;
    out.tex_coord = in.tex_coord;
    out.color = in.color;
    return out;
}

fragment float4 fragment_color(VertexOut in [[stage_in]]) {
    return in.color;
}

fragment float4 fragment_texture(VertexOut in [[stage_in]],
                                texture2d<float> texture [[texture(0)]],
                                sampler sampler [[sampler(0)]]) {
    return texture.sample(sampler, in.tex_coord) * in.color;
}

fragment float4 fragment_text(VertexOut in [[stage_in]],
                             texture2d<float> sdf_atlas [[texture(0)]],
                             sampler sampler [[sampler(0)]]) {
    float dist = sdf_atlas.sample(sampler, in.tex_coord).r;
    float alpha = smoothstep(0.5 - 0.05, 0.5 + 0.05, dist);
    return float4(in.color.rgb, in.color.a * alpha);
}
)";

// RenderEngine Implementation

RenderEngine::RenderEngine() : vertex_offset_(0), index_offset_(0), next_layer_id_(1) {
}

void RenderEngine::initialize(id<MTLDevice> device, CAMetalLayer* layer) {
    device_ = device;
    metal_layer_ = layer;
    metal_layer_.device = device;
    metal_layer_.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metal_layer_.framebufferOnly = NO;
    metal_layer_.maximumDrawableCount = 3; // Triple buffering
    
    // Create command queue
    command_queue_ = [device_ newCommandQueue];
    
    // Initialize command pool
    command_pool_.initialize(device_);
    
    // Initialize texture atlas
    texture_atlas_.initialize(device_);
    
    // Initialize font cache
    font_cache_.initialize(device_);
    
    // Initialize compute engine
    compute_engine_.initialize(device_);
    
    // Build shaders and pipelines
    buildShaders();
    buildPipelines();
    createBuffers();
}

void RenderEngine::buildShaders() {
    NSError* error = nil;
    
    shader_library_ = [device_ newLibraryWithSource:[NSString stringWithUTF8String:vertexShaderSource]
                                          options:nil
                                            error:&error];
    
    if (error) {
        NSLog(@"Shader compilation error: %@", error);
    }
}

void RenderEngine::buildPipelines() {
    MTLRenderPipelineDescriptor* desc = [[MTLRenderPipelineDescriptor alloc] init];
    
    // Color pipeline
    id<MTLFunction> vertexFn = [shader_library_ newFunctionWithName:@"vertex_main"];
    id<MTLFunction> colorFragmentFn = [shader_library_ newFunctionWithName:@"fragment_color"];
    
    desc.vertexFunction = vertexFn;
    desc.fragmentFunction = colorFragmentFn;
    desc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    
    NSError* error = nil;
    color_pipeline_ = [device_ newRenderPipelineStateWithDescriptor:desc error:&error];
    if (error) {
        NSLog(@"Color pipeline error: %@", error);
    }
    
    // Texture pipeline
    id<MTLFunction> textureFragmentFn = [shader_library_ newFunctionWithName:@"fragment_texture"];
    desc.fragmentFunction = textureFragmentFn;
    texture_pipeline_ = [device_ newRenderPipelineStateWithDescriptor:desc error:&error];
    
    // Text/SDF pipeline
    id<MTLFunction> textFragmentFn = [shader_library_ newFunctionWithName:@"fragment_text"];
    desc.fragmentFunction = textFragmentFn;
    text_pipeline_ = [device_ newRenderPipelineStateWithDescriptor:desc error:&error];
    
    // Depth stencil state for clipping
    MTLDepthStencilDescriptor* depthDesc = [[MTLDepthStencilDescriptor alloc] init];
    depth_state_ = [device_ newDepthStencilStateWithDescriptor:depthDesc];
}

void RenderEngine::createBuffers() {
    // Create large vertex/index buffers (ring buffer style)
    const NSUInteger vertexBufferSize = 1024 * 1024 * sizeof(Vertex); // 1MB vertices
    const NSUInteger indexBufferSize = 512 * 1024 * sizeof(uint32_t);  // 512KB indices
    
    vertex_buffer_ = [device_ newBufferWithLength:vertexBufferSize
                                          options:MTLResourceStorageModeShared];
    index_buffer_ = [device_ newBufferWithLength:indexBufferSize
                                         options:MTLResourceStorageModeShared];
    
    // Uniform buffer (triple buffered)
    uniform_buffer_ = [device_ newBufferWithLength:3 * sizeof(simd_float4x4) * 16
                                           options:MTLResourceStorageModeShared];
}

void RenderEngine::beginFrame() {
    render_queue_.clear();
    vertex_offset_ = 0;
    index_offset_ = 0;
    
    // Reset stats
    stats_.draw_calls.store(0);
    stats_.triangles.store(0);
    stats_.texture_switches.store(0);
    stats_.shader_switches.store(0);
    
    // Clear damage if requested
}

void RenderEngine::endFrame() {
    // Get drawable
    id<CAMetalDrawable> drawable = [metal_layer_ nextDrawable];
    if (!drawable) return;
    
    // Acquire command buffer
    id<MTLCommandBuffer> cmd_buffer = command_pool_.acquire();
    
    MTLRenderPassDescriptor* pass = [[MTLRenderPassDescriptor alloc] init];
    pass.colorAttachments[0].texture = drawable.texture;
    pass.colorAttachments[0].loadAction = MTLLoadActionClear;
    pass.colorAttachments[0].storeAction = MTLStoreActionStore;
    pass.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);
    
    // Apply damage rect if using incremental rendering
    if (!damage_rects_.empty()) {
        // Set scissor to damage rect
        simd_float4 damage = damage_rects_.back();
        // Convert to pixel coordinates
    }
    
    id<MTLRenderCommandEncoder> encoder = [cmd_buffer renderCommandEncoderWithDescriptor:pass];
    
    // Set common state
    [encoder setCullMode:MTLCullModeNone];
    [encoder setDepthStencilState:depth_state_];
    
    // Bin commands to tiles for mobile optimization
    binCommandsToTiles();
    
    // Submit all render commands
    submitCommands(cmd_buffer, encoder);
    
    // Composite layers
    compositeLayers(cmd_buffer);
    
    [encoder endEncoding];
    
    // Present
    [cmd_buffer presentDrawable:drawable];
    [cmd_buffer commit];
    
    command_pool_.nextFrame();
    
    // Store previous damage
    previous_damage_ = damage_rects_;
    damage_rects_.clear();
}

void RenderEngine::submitCommands(id<MTLCommandBuffer> cmd_buffer,
                                  id<MTLRenderCommandEncoder> encoder) {
    (void)cmd_buffer;
    
    id<MTLRenderPipelineState> current_pipeline = nil;
    id<MTLTexture> current_texture = nil;
    simd_float4x4 current_transform = simd_diagonal_matrix(1.0f);
    
    for (const auto& cmd : render_queue_) {
        // Switch pipeline if needed
        id<MTLRenderPipelineState> pipeline = nil;
        switch (cmd.type) {
            case PRIM_RECT:
            case PRIM_PATH:
                pipeline = color_pipeline_;
                break;
            case PRIM_IMAGE:
            case PRIM_LAYER:
                pipeline = texture_pipeline_;
                break;
            case PRIM_TEXT:
                pipeline = text_pipeline_;
                break;
            default:
                pipeline = color_pipeline_;
                break;
        }
        
        if (pipeline != current_pipeline) {
            [encoder setRenderPipelineState:pipeline];
            current_pipeline = pipeline;
            stats_.shader_switches.fetch_add(1);
        }
        
        // Set texture if needed
        if (cmd.texture && cmd.texture != current_texture) {
            [encoder setFragmentTexture:cmd.texture atIndex:0];
            current_texture = cmd.texture;
            stats_.texture_switches.fetch_add(1);
        }
        
        // Set transform if changed
        if (!simd_equal(cmd.transform, current_transform)) {
            simd_float4x4* uniforms = (simd_float4x4*)[uniform_buffer_ contents];
            uniforms[0] = cmd.transform;
            [encoder setVertexBuffer:uniform_buffer_ offset:0 atIndex:1];
            current_transform = cmd.transform;
        }
        
        // Set vertex/index buffers
        if (cmd.vertex_count > 0) {
            [encoder setVertexBuffer:vertex_buffer_ 
                              offset:cmd.vertex_offset * sizeof(Vertex)
                             atIndex:0];
            
            if (cmd.index_count > 0) {
                [encoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                    indexCount:cmd.index_count
                                     indexType:MTLIndexTypeUInt32
                                   indexBuffer:index_buffer_
                             indexBufferOffset:cmd.index_offset * sizeof(uint32_t)];
            } else {
                [encoder drawPrimitives:MTLPrimitiveTypeTriangle
                            vertexStart:0
                            vertexCount:cmd.vertex_count];
            }
            
            stats_.draw_calls.fetch_add(1);
            stats_.triangles.fetch_add(cmd.index_count / 3);
        }
    }
}

void RenderEngine::binCommandsToTiles() {
    // Simple binning - group commands by tile for better cache locality
    // This is especially important for mobile GPUs
    tiles_.clear();
    
    // Get viewport dimensions
    CGSize drawableSize = metal_layer_.drawableSize;
    uint32_t tilesX = (uint32_t)ceil(drawableSize.width / TILE_SIZE);
    uint32_t tilesY = (uint32_t)ceil(drawableSize.height / TILE_SIZE);
    
    tiles_.resize(tilesX * tilesY);
    
    // Initialize tiles
    for (uint32_t y = 0; y < tilesY; y++) {
        for (uint32_t x = 0; x < tilesX; x++) {
            Tile& tile = tiles_[y * tilesX + x];
            tile.x = x;
            tile.y = y;
            tile.command_indices.clear();
        }
    }
    
    // Bin commands to tiles based on their bounds
    for (size_t i = 0; i < render_queue_.size(); i++) {
        const RenderCommand& cmd = render_queue_[i];
        
        // Calculate tile coverage
        float minX = cmd.clip_rect.x;
        float minY = cmd.clip_rect.y;
        float maxX = minX + cmd.clip_rect.z;
        float maxY = minY + cmd.clip_rect.w;
        
        uint32_t startTileX = (uint32_t)fmax(0, minX / TILE_SIZE);
        uint32_t startTileY = (uint32_t)fmax(0, minY / TILE_SIZE);
        uint32_t endTileX = (uint32_t)fmin(tilesX - 1, maxX / TILE_SIZE);
        uint32_t endTileY = (uint32_t)fmin(tilesY - 1, maxY / TILE_SIZE);
        
        for (uint32_t ty = startTileY; ty <= endTileY; ty++) {
            for (uint32_t tx = startTileX; tx <= endTileX; tx++) {
                tiles_[ty * tilesX + tx].command_indices.push_back((uint32_t)i);
            }
        }
    }
}

void RenderEngine::compositeLayers(id<MTLCommandBuffer> cmd_buffer) {
    (void)cmd_buffer;
    // Layer compositing happens here
    // For now, simple pass-through
}

void RenderEngine::renderLayoutTree(Layout::LayoutNode* root, const simd_float4& viewport) {
    if (!root) return;
    
    // Generate render commands from layout tree
    // Walk the tree and create primitives
    
    std::function<void(Layout::LayoutNode*)> visitNode;
    visitNode = [this, &viewport, &visitNode](Layout::LayoutNode* node) {
        if (!node) return;
        
        // Skip if outside viewport (culling)
        simd_float4 box = node->box.getBorderRect();
        if (box.x > viewport.z || box.y > viewport.w ||
            box.x + box.z < 0 || box.y + box.w < 0) {
            return;
        }
        
        // Render background
        if (node->style.background_color.type != CSS::NONE) {
            RenderCommand cmd;
            cmd.type = PRIM_RECT;
            cmd.clip_rect = box;
            cmd.color = node->style.background_color.color.vec;
            cmd.opacity = node->style.opacity.number;
            
            generateRect(box, 0, node->style.background_color.color.vec);
            
            submit(cmd);
        }
        
        // Render text content
        if (node->dom_node && node->dom_node->type == HTMLParser::DOMBuilder::Node::TEXT) {
            TextRun run;
            run.position = simd_make_float2(node->box.content_x, node->box.content_y);
            run.font_size = node->style.font_size.length.toPixels();
            // Set color from computed style
            if (node->style.color.type == CSS::COLOR) {
                run.color = *(uint32_t*)&node->style.color.color.vec;
            }
            
            renderText(run);
        }
        
        // Visit children
        Layout::LayoutNode* child = node->first_child.load(std::memory_order_acquire);
        while (child) {
            visitNode(child);
            child = child->next_sibling.load(std::memory_order_acquire);
        }
    };
    
    visitNode(root);
}

void RenderEngine::generateRect(const simd_float4& rect, float radius, uint32_t color) {
    (void)radius; // TODO: Rounded corners
    
    // Generate quad vertices
    Vertex* vertices = (Vertex*)[vertex_buffer_ contents];
    vertices += vertex_offset_;
    
    float x = rect.x;
    float y = rect.y;
    float w = rect.z;
    float h = rect.w;
    
    float z = 0.0f;
    simd_float4 c = *(simd_float4*)&color;
    
    // Triangle 1
    vertices[0] = {{x, y}, {0, 0}, c, z};
    vertices[1] = {{x + w, y}, {1, 0}, c, z};
    vertices[2] = {{x, y + h}, {0, 1}, c, z};
    
    // Triangle 2
    vertices[3] = {{x + w, y}, {1, 0}, c, z};
    vertices[4] = {{x + w, y + h}, {1, 1}, c, z};
    vertices[5] = {{x, y + h}, {0, 1}, c, z};
    
    vertex_offset_ += 6;
}

void RenderEngine::submit(const RenderCommand& cmd) {
    render_queue_.push_back(cmd);
}

uint32_t RenderEngine::createLayer(const simd_float4& bounds, bool opaque) {
    (void)opaque;
    
    CompositorLayer layer;
    layer.layer_id = next_layer_id_++;
    layer.bounds = bounds;
    layer.needs_redraw = true;
    
    // Create backing texture
    MTLTextureDescriptor* desc = [[MTLTextureDescriptor alloc] init];
    desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
    desc.width = (NSUInteger)bounds.z;
    desc.height = (NSUInteger)bounds.w;
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModePrivate;
    
    layer.backing_texture = [device_ newTextureWithDescriptor:desc];
    
    layers_.push_back(layer);
    return layer.layer_id;
}

void RenderEngine::updateLayerTransform(uint32_t layer_id, const simd_float4x4& transform) {
    for (auto& layer : layers_) {
        if (layer.layer_id == layer_id) {
            layer.transform = transform;
            return;
        }
    }
}

void RenderEngine::updateLayerOpacity(uint32_t layer_id, float opacity) {
    for (auto& layer : layers_) {
        if (layer.layer_id == layer_id) {
            layer.opacity = opacity;
            return;
        }
    }
}

void RenderEngine::addDamageRect(const simd_float4& rect) {
    damage_rects_.push_back(rect);
}

void RenderEngine::clearDamage() {
    damage_rects_.clear();
}

void RenderEngine::renderText(const TextRun& run) {
    // Submit text rendering command
    RenderCommand cmd;
    cmd.type = PRIM_TEXT;
    cmd.position = run.position;
    
    // Font atlas texture
    cmd.texture = run.font_atlas;
    cmd.atlas_scale = run.atlas_scale;
    
    submit(cmd);
}

void RenderEngine::renderRect(const simd_float4& rect, float radius, simd_float4 color, float opacity) {
    RenderCommand cmd;
    cmd.type = PRIM_RECT;
    cmd.clip_rect = rect;
    cmd.color = color;
    cmd.opacity = opacity;
    
    generateRect(rect, radius, *(uint32_t*)&color);
    submit(cmd);
}

void RenderEngine::renderImage(id<MTLTexture> texture, const simd_float4& rect, const simd_float4& tex_coords) {
    RenderCommand cmd;
    cmd.type = PRIM_IMAGE;
    cmd.texture = texture;
    cmd.clip_rect = rect;
    cmd.tex_coords[0] = tex_coords.x;
    cmd.tex_coords[1] = tex_coords.y;
    cmd.tex_coords[2] = tex_coords.z;
    cmd.tex_coords[3] = tex_coords.w;
    
    submit(cmd);
}

void RenderEngine::waitForGPU() {
    [command_queue_ insertDebugMarker:@"Wait"];
    id<MTLCommandBuffer> cmd = [command_queue_ commandBuffer];
    [cmd commit];
    [cmd waitUntilCompleted];
}

// TextureAtlas Implementation
void TextureAtlas::initialize(id<MTLDevice> device, uint32_t size) {
    atlas_size_ = size;
    
    MTLTextureDescriptor* desc = [[MTLTextureDescriptor alloc] init];
    desc.pixelFormat = MTLPixelFormatBGRA8Unorm;
    desc.width = size;
    desc.height = size;
    desc.usage = MTLTextureUsageShaderRead | MTLTextureUsagePixelFormatWrite;
    desc.storageMode = MTLStorageModeShared;
    
    atlas_texture_ = [device newTextureWithDescriptor:desc];
    
    // Initialize with one large free region
    free_regions_.push_back({0, 0, (uint16_t)size, (uint16_t)size, 0, 0, 1, 1});
}

bool TextureAtlas::allocate(uint16_t w, uint16_t h, Region& out_region) {
    // Simple first-fit allocation
    for (auto& region : free_regions_) {
        if (region.w >= w && region.h >= h) {
            out_region.x = region.x;
            out_region.y = region.y;
            out_region.w = w;
            out_region.h = h;
            out_region.u0 = (float)region.x / atlas_size_;
            out_region.v0 = (float)region.y / atlas_size_;
            out_region.u1 = (float)(region.x + w) / atlas_size_;
            out_region.v1 = (float)(region.y + h) / atlas_size_;
            
            // Split remaining space (simplified)
            region.x += w;
            
            return true;
        }
    }
    return false;
}

void TextureAtlas::upload(const Region& region, const void* data, size_t pitch) {
    MTLRegion r = MTLRegionMake2D(region.x, region.y, region.w, region.h);
    [atlas_texture_ replaceRegion:r
                      mipmapLevel:0
                        withBytes:data
                      bytesPerRow:pitch];
}

// FontCache Implementation
void FontCache::initialize(id<MTLDevice> device) {
    atlas_.initialize(device, 4096);
}

const FontCache::GlyphCache* FontCache::getGlyph(const FontKey& font, uint32_t codepoint) {
    uint64_t key = ((uint64_t)font.size << 32) | codepoint;
    
    auto it = glyph_cache_.find(key);
    if (it != glyph_cache_.end()) {
        return &it->second;
    }
    
    // Rasterize and cache new glyph
    // For now, return nullptr
    return nullptr;
}

// ComputeEngine Implementation
void ComputeEngine::initialize(id<MTLDevice> device) {
    device_ = device;
    
    // Load compute shaders
    // TODO: Implement compute pipeline
}

void ComputeEngine::computeFlexLayoutGPU(const std::vector<Layout::LayoutNode*>& items,
                                         float available_width,
                                         float available_height,
                                         std::vector<float>& out_positions) {
    (void)items;
    (void)available_width;
    (void)available_height;
    (void)out_positions;
    // TODO: GPU flex layout
}

void ComputeEngine::shapeTextGPU(const TextRun& run,
                                id<MTLBuffer> glyph_buffer,
                                id<MTLBuffer> position_buffer) {
    (void)run;
    (void)glyph_buffer;
    (void)position_buffer;
    // TODO: GPU text shaping
}

void ComputeEngine::cullLayersGPU(const std::vector<CompositorLayer>& layers,
                                 simd_float4 view_rect,
                                 id<MTLBuffer> visible_indices) {
    (void)layers;
    (void)view_rect;
    (void)visible_indices;
    // TODO: GPU culling
}

// CommandBufferPool Implementation
void CommandBufferPool::initialize(id<MTLCommandQueue> queue, size_t pool_size) {
    queue_ = queue;
    buffers_.resize(pool_size);
    
    for (size_t i = 0; i < pool_size; i++) {
        buffers_[i].buffer = [queue_ commandBuffer];
        buffers_[i].in_use.store(false);
    }
}

id<MTLCommandBuffer> CommandBufferPool::acquire() {
    uint64_t frame = current_frame_.load();
    
    for (auto& pooled : buffers_) {
        bool expected = false;
        if (pooled.in_use.compare_exchange_strong(expected, true)) {
            pooled.frame_id.store(frame);
            return pooled.buffer;
        }
    }
    
    // All buffers in use, create new one
    return [queue_ commandBuffer];
}

void CommandBufferPool::release(id<MTLCommandBuffer> buffer) {
    for (auto& pooled : buffers_) {
        if (pooled.buffer == buffer) {
            pooled.in_use.store(false);
            return;
        }
    }
}

} // namespace Render
} // namespace Vortex
