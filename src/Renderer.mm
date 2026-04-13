#include "vortex/Renderer.h"
#import <MetalKit/MetalKit.h>
#include <simd/simd.h>
#include <cstring>

namespace Vortex {

MetalRenderer::MetalRenderer()
    : device_(nullptr)
    , command_queue_(nullptr)
    , metal_layer_(nullptr)
    , pipeline_state_(nullptr)
    , depth_state_(nullptr)
    , current_frame_(0)
    , tile_width_(256)
    , tile_height_(256)
{
}

MetalRenderer::~MetalRenderer() {
    shutdown();
}

bool MetalRenderer::initialize(id<MTLDevice> device, CAMetalLayer* layer) {
    device_ = device;
    metal_layer_ = layer;
    
    if (!device_) {
        return false;
    }
    
    command_queue_ = [device_ newCommandQueue];
    if (!command_queue_) {
        return false;
    }
    
    // Create simple pipeline state
    id<MTLLibrary> library = [device_ newDefaultLibrary];
    if (!library) {
        // Would create library from source if no default
    }
    
    current_frame_ = 0;
    
    return true;
}

void MetalRenderer::shutdown() {
    pipeline_state_ = nil;
    depth_state_ = nil;
    command_queue_ = nil;
    device_ = nil;
    metal_layer_ = nil;
}

void MetalRenderer::beginFrame() {
    current_frame_++;
    command_queue.clear();
}

void MetalRenderer::endFrame() {
    if (!metal_layer_ || command_queue.empty()) {
        return;
    }
    
    id<CAMetalDrawable> drawable = [metal_layer_ nextDrawable];
    if (!drawable) {
        return;
    }
    
    MTLRenderPassDescriptor* passDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
    passDescriptor.colorAttachments[0].texture = drawable.texture;
    passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 1.0, 1.0, 1.0);
    
    id<MTLCommandBuffer> commandBuffer = [command_queue_ commandBuffer];
    
    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    
    encodeRenderCommands(encoder);
    
    [encoder endEncoding];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

void MetalRenderer::renderLayoutBox(const std::shared_ptr<LayoutBox>& layout_root) {
    if (!layout_root) return;
    
    // Add render commands for this box
    RenderCommand cmd;
    cmd.type = RenderCommand::RECT;
    cmd.rect = simd_make_float4(
        layout_root->position.x,
        layout_root->position.y,
        layout_root->size.x,
        layout_root->size.y
    );
    cmd.color = Color(0.9f, 0.9f, 0.9f, 1.0f);
    cmd.corner_radius = 0.0f;
    cmd.opacity = 1.0f;
    
    submitCommand(cmd);
    
    // Recurse into children
    for (auto& child : layout_root->children) {
        renderLayoutBox(child);
    }
}

void MetalRenderer::submitCommand(const RenderCommand& cmd) {
    command_queue.push_back(cmd);
}

void MetalRenderer::setViewport(float x, float y, float width, float height) {
    // Would set viewport on encoder
}

void MetalRenderer::clear(const Color& color) {
    // Clearing is handled in beginFrame with clear color
}

id<MTLBuffer> MetalRenderer::allocateBuffer(size_t size, uint32_t frame_id) {
    // Check for reusable buffer
    for (auto& buf : buffer_pool_) {
        if (buf.size >= size && buf.frame_id < frame_id - 2) {
            buf.frame_id = frame_id;
            buf.used = 0;
            return buf.buffer;
        }
    }
    
    // Allocate new buffer
    id<MTLBuffer> buffer = [device_ newBufferWithLength:size options:MTLResourceStorageModeShared];
    
    GPUBuffer gpu_buf;
    gpu_buf.buffer = buffer;
    gpu_buf.size = size;
    gpu_buf.used = 0;
    gpu_buf.frame_id = frame_id;
    buffer_pool_.push_back(gpu_buf);
    
    return buffer;
}

id<MTLTexture> MetalRenderer::getCachedTexture(uint64_t hash, simd_float2 size) {
    for (auto& tex : texture_cache_) {
        if (tex.hash == hash && tex.last_used_frame > current_frame_ - 60) {
            tex.last_used_frame = current_frame_;
            return tex.texture;
        }
    }
    return nil;
}

void MetalRenderer::updateTextureCache(uint64_t hash, id<MTLTexture> texture, simd_float2 size) {
    for (auto& tex : texture_cache_) {
        if (tex.hash == hash) {
            tex.last_used_frame = current_frame_;
            return;
        }
    }
    
    TextureCache cache;
    cache.texture = texture;
    cache.hash = hash;
    cache.last_used_frame = current_frame_;
    cache.size = size;
    texture_cache_.push_back(cache);
}

void MetalRenderer::flushTextureCache() {
    // Remove old textures
    auto it = texture_cache_.begin();
    while (it != texture_cache_.end()) {
        if (it->last_used_frame < current_frame_ - 120) {
            it = texture_cache_.erase(it);
        } else {
            ++it;
        }
    }
}

void MetalRenderer::setTileSize(int width, int height) {
    tile_width_ = width;
    tile_height_ = height;
}

void MetalRenderer::renderTiles(const std::vector<std::shared_ptr<LayoutBox>>& tiles) {
    // Would render each tile separately
}

void MetalRenderer::addDamageRect(simd_float4 rect) {
    damage_rects_.push_back(rect);
}

void MetalRenderer::clearDamageRects() {
    damage_rects_.clear();
}

std::vector<simd_float4> MetalRenderer::getDamageRects() const {
    return damage_rects_;
}

void MetalRenderer::encodeRenderCommands(id<MTLRenderCommandEncoder> encoder) {
    for (const auto& cmd : command_queue) {
        switch (cmd.type) {
            case RenderCommand::RECT:
                renderRect(cmd, encoder);
                break;
            case RenderCommand::TEXT:
                renderText(cmd, encoder);
                break;
            case RenderCommand::IMAGE:
                renderImage(cmd, encoder);
                break;
            default:
                break;
        }
    }
}

void MetalRenderer::renderRect(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder) {
    // Would set up vertex buffer and render rect
}

void MetalRenderer::renderText(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder) {
    // Would render text using CoreText and texture cache
}

void MetalRenderer::renderImage(const RenderCommand& cmd, id<MTLRenderCommandEncoder> encoder) {
    // Would render image texture
}

id<MTLBuffer> MetalRenderer::getQuadVertexBuffer() {
    // Return pre-allocated vertex buffer
    return nil;
}

id<MTLBuffer> MetalRenderer::getQuadIndexBuffer() {
    // Return pre-allocated index buffer
    return nil;
}

// DamageTracker implementation
void DamageTracker::addRect(simd_float4 rect) {
    damage_rects_.push_back(rect);
}

void DamageTracker::clear() {
    damage_rects_.clear();
}

bool DamageTracker::needsRepaint(simd_float4 area) const {
    for (const auto& rect : damage_rects_) {
        // Check if damage rect intersects with area
        if (rect.x < area.x + area.z && rect.x + rect.z > area.x &&
            rect.y < area.y + area.w && rect.y + rect.w > area.y) {
            return true;
        }
    }
    return false;
}

std::vector<simd_float4> DamageTracker::getOptimizedRects() const {
    // Would merge overlapping rects
    return damage_rects_;
}

bool DamageTracker::canMerge(simd_float4 a, simd_float4 b) const {
    float dx = std::min(a.x + a.z, b.x + b.z) - std::max(a.x, b.x);
    float dy = std::min(a.y + a.w, b.y + b.w) - std::max(a.y, b.y);
    return dx > -MERGE_THRESHOLD && dy > -MERGE_THRESHOLD;
}

simd_float4 DamageTracker::mergeRects(simd_float4 a, simd_float4 b) const {
    float x = std::min(a.x, b.x);
    float y = std::min(a.y, b.y);
    float w = std::max(a.x + a.z, b.x + b.z) - x;
    float h = std::max(a.y + a.w, b.y + b.w) - y;
    return simd_make_float4(x, y, w, h);
}

} // namespace Vortex
