#pragma once
#include "Layout.h"
#include <simd/simd.h>
#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.h>
#include <vector>
#include <memory>

namespace Vortex {

struct RenderCommand {
    enum Type { RECT, TEXT, IMAGE, CLIP, BLEND };
    Type type;
    simd_float4 rect;
    Color color;
    float corner_radius;
    std::string text;
    float font_size;
    simd_float2 position;
    void* texture_handle;
    float opacity;
};

struct GPUBuffer {
    id<MTLBuffer> buffer;
    size_t size;
    size_t used;
    uint32_t frame_id;
};

struct TextureCache {
    id<MTLTexture> texture;
    uint64_t hash;
    uint32_t last_used_frame;
    simd_float2 size;
};

class MetalRenderer {
public:
    MetalRenderer();
    ~MetalRenderer();
    
    bool initialize(id<MTLDevice> device, CAMetalLayer* layer);
    void shutdown();
    
    void beginFrame();
    void endFrame();
    
    void renderLayoutBox(const std::shared_ptr<LayoutBox>& layout_root);
    void submitCommand(const RenderCommand& cmd);
    
    void setViewport(float x, float y, float width, float height);
    void clear(const Color& color);
    
    // GPU resource management
    id<MTLBuffer> allocateBuffer(size_t size, uint32_t frame_id);
    id<MTLTexture> getCachedTexture(uint64_t hash, simd_float2 size);
    void updateTextureCache(uint64_t hash, id<MTLTexture> texture, simd_float2 size);
    
    void flushTextureCache();
    
    // Tile-based optimization
    void setTileSize(int width, int height);
    void renderTiles(const std::vector<std::shared_ptr<LayoutBox>>& tiles);
    
    // Damage tracking
    void addDamageRect(simd_float4 rect);
    void clearDamageRects();
    std::vector<simd_float4> getDamageRects() const;
    
private:
    id<MTLDevice> device_;
    id<MTLCommandQueue> command_queue_;
    CAMetalLayer* metal_layer_;
    id<MTLRenderPipelineState> pipeline_state_;
    id<MTLDepthStencilState> depth_state_;
    
    std::vector<GPUBuffer> buffer_pool_;
    std::vector<TextureCache> texture_cache_;
    std::vector<RenderCommand> command_queue;
    std::vector<simd_float4> damage_rects_;
    
    uint32_t current_frame_;
    int tile_width_;
    int tile_height_;
    
    void encodeRenderCommands(id<MTLRenderCommandEncoder> encoder);
    void renderRect(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder);
    void renderText(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder);
    void renderImage(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder);
    
    id<MTLBuffer> getQuadVertexBuffer();
    id<MTLBuffer> getQuadIndexBuffer();
};

// Damage tracker for incremental rendering
class DamageTracker {
public:
    void addRect(simd_float4 rect);
    void clear();
    bool needsRepaint(simd_float4 area) const;
    std::vector<simd_float4> getOptimizedRects() const;
    
private:
    std::vector<simd_float4> damage_rects_;
    static constexpr float MERGE_THRESHOLD = 10.0f;
    
    bool canMerge(simd_float4 a, simd_float4 b) const;
    simd_float4 mergeRects(simd_float4 a, simd_float4 b) const;
};

} // namespace Vortex
