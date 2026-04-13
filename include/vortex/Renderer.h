#pragma once
#include "Layout.h"
#include "Color.h"
#include <simd/simd.h>
#include <vector>
#include <memory>

// Forward declarations for Metal types to avoid including Metal.h in C++ headers
#ifdef __OBJC__
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#else
// Opaque types for C++
typedef void* id_MTLDevice;
typedef void* id_MTLBuffer;
typedef void* id_MTLTexture;
typedef void* id_MTLCommandQueue;
typedef void* id_MTLRenderPipelineState;
typedef void* id_MTLDepthStencilState;
typedef void* id_MTLRenderCommandEncoder;
typedef void* id_MTLCommandBuffer;
typedef void* CAMetalLayer;
#endif

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
#ifdef __OBJC__
    id<MTLBuffer> buffer;
#else
    id_MTLBuffer buffer;
#endif
    size_t size;
    size_t used;
    uint32_t frame_id;
};

struct TextureCache {
#ifdef __OBJC__
    id<MTLTexture> texture;
#else
    id_MTLTexture texture;
#endif
    uint64_t hash;
    uint32_t last_used_frame;
    simd_float2 size;
};

class MetalRenderer {
public:
    MetalRenderer();
    ~MetalRenderer();
    
#ifdef __OBJC__
    bool initialize(id<MTLDevice> device, CAMetalLayer* layer);
#else
    bool initialize(id_MTLDevice device, CAMetalLayer* layer);
#endif
    void shutdown();
    
    void beginFrame();
    void endFrame();
    
    void renderLayoutBox(const std::shared_ptr<LayoutBox>& layout_root);
    void submitCommand(const RenderCommand& cmd);
    
    void setViewport(float x, float y, float width, float height);
    void clear(const Color& color);
    
    // GPU resource management
#ifdef __OBJC__
    id<MTLBuffer> allocateBuffer(size_t size, uint32_t frame_id);
    id<MTLTexture> getCachedTexture(uint64_t hash, simd_float2 size);
    void updateTextureCache(uint64_t hash, id<MTLTexture> texture, simd_float2 size);
    void encodeRenderCommands(id<MTLRenderCommandEncoder> encoder);
    void renderRect(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder);
    void renderText(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder);
    void renderImage(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder);
#else
    id_MTLBuffer allocateBuffer(size_t size, uint32_t frame_id);
    id_MTLTexture getCachedTexture(uint64_t hash, simd_float2 size);
    void updateTextureCache(uint64_t hash, id_MTLTexture texture, simd_float2 size);
#endif
    
    void flushTextureCache();
    
    // Tile-based optimization
    void setTileSize(int width, int height);
    void renderTiles(const std::vector<std::shared_ptr<LayoutBox>>& tiles);
    
    // Damage tracking
    void addDamageRect(simd_float4 rect);
    void clearDamageRects();
    std::vector<simd_float4> getDamageRects() const;
    
private:
#ifdef __OBJC__
    id<MTLDevice> device_;
    id<MTLCommandQueue> command_queue_;
    id<MTLRenderPipelineState> pipeline_state_;
    id<MTLDepthStencilState> depth_state_;
#else
    id_MTLDevice device_;
    id_MTLCommandQueue command_queue_;
    id_MTLRenderPipelineState pipeline_state_;
    id_MTLDepthStencilState depth_state_;
#endif
    CAMetalLayer* metal_layer_;
    
    std::vector<GPUBuffer> buffer_pool_;
    std::vector<TextureCache> texture_cache_;
    std::vector<RenderCommand> command_queue;
    std::vector<simd_float4> damage_rects_;
    
    uint32_t current_frame_;
    int tile_width_;
    int tile_height_;
    
#ifdef __OBJC__
    id<MTLBuffer> getQuadVertexBuffer();
    id<MTLBuffer> getQuadIndexBuffer();
#else
    id_MTLBuffer getQuadVertexBuffer();
    id_MTLBuffer getQuadIndexBuffer();
#endif
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
