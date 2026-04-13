#pragma once

#include "Core.h"
#include "Layout.h"
#include "CSS.h"
#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.h>
#include <simd/simd.h>

namespace Vortex {

// Metal-accelerated renderer
// Zero-copy GPU rendering with tile-based damage tracking

namespace Render {

// Render primitive types
enum PrimitiveType {
    PRIM_RECT,           // Rectangle with rounded corners
    PRIM_TEXT,           // Text glyph run
    PRIM_IMAGE,          // Image/texture
    PRIM_PATH,           // SVG/bezier path
    PRIM_LAYER,          // Composited layer
    PRIM_EFFECT          // Filter/effect
};

// GPU buffer alignment
constexpr size_t GPU_BUFFER_ALIGNMENT = 256;

// Command buffer pool for zero-allocation submission
class CommandBufferPool {
    struct alignas(GPU_BUFFER_ALIGNMENT) PooledBuffer {
        id<MTLCommandBuffer> buffer;
        std::atomic<bool> in_use{false};
        std::atomic<uint64_t> frame_id{0};
    };
    
    std::vector<PooledBuffer> buffers_;
    id<MTLCommandQueue> queue_;
    std::atomic<uint64_t> current_frame_{0};
    
public:
    void initialize(id<MTLDevice> device, size_t pool_size = 16);
    id<MTLCommandBuffer> acquire();
    void release(id<MTLCommandBuffer> buffer);
    void nextFrame() { current_frame_.fetch_add(1); }
};

// Render command encoded for GPU execution
struct RenderCommand {
    PrimitiveType type;
    
    // Transform matrix (SIMD float4x4)
    simd_float4x4 transform;
    
    // Clip rect
    simd_float4 clip_rect;
    
    // Opacity and blend mode
    float opacity;
    uint32_t blend_mode;
    
    // Color
    simd_float4 color;
    
    // Texture/Glyph data
    id<MTLTexture> texture;
    float tex_coords[4];  // u0, v0, u1, v1
    
    // Geometry buffer offset
    uint32_t vertex_offset;
    uint32_t vertex_count;
    uint32_t index_offset;
    uint32_t index_count;
    
    // Layer ID for compositing
    uint32_t layer_id;
    float z_depth;
    
    // Effect parameters
    float blur_radius;
    float shadow_offset[2];
    float shadow_blur;
    simd_float4 shadow_color;
    
    // Damage rect for incremental rendering
    simd_float4 damage_rect;
    bool use_damage;
};

// Vertex format for GPU rendering
struct Vertex {
    simd_float2 position;
    simd_float2 tex_coord;
    simd_float4 color;
    float z;
};

// Text run for GPU text rendering
struct TextRun {
    simd_float2 position;
    float font_size;
    uint32_t color;
    
    // Glyph indices and positions
    std::vector<uint16_t> glyph_indices;
    std::vector<simd_float2> glyph_positions;
    
    // Font texture atlas reference
    id<MTLTexture> font_atlas;
    float atlas_scale;
    
    // Bounds for culling
    simd_float4 bounds;
};

// Texture atlas for efficient texture management
class TextureAtlas {
public:
    struct Region {
        uint16_t x, y, w, h;
        float u0, v0, u1, v1;
    };
    
private:
    id<MTLTexture> atlas_texture_;
    std::vector<Region> free_regions_;
    uint32_t atlas_size_;
    
    // Quadtree for packing
    struct Node {
        Region rect;
        Node* children[2];
        bool occupied;
    };
    Node* root_;
    
    Node* insert(Node* node, uint16_t w, uint16_t h);
    
public:
    void initialize(id<MTLDevice> device, uint32_t size = 4096);
    
    // Allocate space in atlas
    bool allocate(uint16_t w, uint16_t h, Region& out_region);
    
    // Upload image data
    void upload(const Region& region, const void* data, size_t pitch);
    
    // Get texture
    id<MTLTexture> texture() const { return atlas_texture_; }
    
    // Defragment (repack)
    void defragment();
};

// Font cache and atlas
class FontCache {
    struct FontKey {
        SIMDString family;
        float size;
        uint32_t weight;
        bool italic;
    };
    
    struct GlyphCache {
        uint16_t atlas_x, atlas_y;
        uint16_t width, height;
        float bearing_x, bearing_y;
        float advance;
    };
    
    // SDF (Signed Distance Field) rendering for crisp text at any scale
    struct SDFGlyph {
        uint8_t* sdf_data;
        uint16_t sdf_size;
        float spread;
    };
    
    TextureAtlas atlas_;
    std::unordered_map<uint64_t, GlyphCache> glyph_cache_;
    std::unordered_map<uint64_t, SDFGlyph> sdf_cache_;
    
    // Generate SDF from raster glyph
    void generateSDF(const void* raster, uint16_t w, uint16_t h, SDFGlyph& sdf);
    
public:
    void initialize(id<MTLDevice> device);
    
    // Get glyph (cached or rasterized)
    const GlyphCache* getGlyph(const FontKey& font, uint32_t codepoint);
    
    // Prepare text for rendering
    void prepareText(const TextRun& run);
};

// Composited layer for efficient scrolling and animations
struct CompositorLayer {
    uint32_t layer_id;
    simd_float4x4 transform;
    simd_float4 bounds;
    float opacity;
    
    // Backing texture
    id<MTLTexture> backing_texture;
    bool needs_redraw;
    
    // Damage rect since last render
    simd_float4 damage_rect;
    
    // Children layers (for nested compositing)
    std::vector<uint32_t> child_layers;
    
    // Scroll optimization
    float scroll_x, scroll_y;
    simd_float4 visible_rect;
};

// GPU compute shaders for layout calculations
class ComputeEngine {
    id<MTLDevice> device_;
    id<MTLComputePipelineState> flex_layout_shader_;
    id<MTLComputePipelineState> text_shaping_shader_;
    id<MTLComputePipelineState> culling_shader_;
    
public:
    void initialize(id<MTLDevice> device);
    
    // GPU-accelerated flexbox layout
    void computeFlexLayoutGPU(const std::vector<Layout::LayoutNode*>& items,
                              float available_width,
                              float available_height,
                              std::vector<float>& out_positions);
    
    // GPU text shaping (parallel per character)
    void shapeTextGPU(const TextRun& run,
                     id<MTLBuffer> glyph_buffer,
                     id<MTLBuffer> position_buffer);
    
    // Frustum/rect culling
    void cullLayersGPU(const std::vector<CompositorLayer>& layers,
                      simd_float4 view_rect,
                      id<MTLBuffer> visible_indices);
};

// Main render engine
class RenderEngine {
public:
    // Rendering statistics
    struct Stats {
        std::atomic<uint32_t> draw_calls{0};
        std::atomic<uint32_t> triangles{0};
        std::atomic<uint32_t> texture_switches{0};
        std::atomic<uint32_t> shader_switches{0};
        std::atomic<double> cpu_time{0};
        std::atomic<double> gpu_time{0};
    };
    
private:
    // Metal objects
    id<MTLDevice> device_;
    id<MTLCommandQueue> command_queue_;
    CAMetalLayer* metal_layer_;
    
    // Pipeline states
    id<MTLRenderPipelineState> color_pipeline_;
    id<MTLRenderPipelineState> texture_pipeline_;
    id<MTLRenderPipelineState> text_pipeline_;
    id<MTLRenderPipelineState> layer_pipeline_;
    id<MTLDepthStencilState> depth_state_;
    
    // Buffers
    id<MTLBuffer> vertex_buffer_;
    id<MTLBuffer> index_buffer_;
    id<MTLBuffer> uniform_buffer_;
    uint32_t vertex_offset_;
    uint32_t index_offset_;
    
    // Resource management
    TextureAtlas texture_atlas_;
    FontCache font_cache_;
    CommandBufferPool command_pool_;
    ComputeEngine compute_engine_;
    
    // Layer compositor
    std::vector<CompositorLayer> layers_;
    uint32_t next_layer_id_;
    
    // Render queue
    std::vector<RenderCommand> render_queue_;
    
    // Tile-based rendering (for mobile optimization)
    static constexpr uint32_t TILE_SIZE = 32;
    struct Tile {
        uint32_t x, y;
        std::vector<uint32_t> command_indices;
    };
    std::vector<Tile> tiles_;
    
    // Damage tracking for incremental rendering
    std::vector<simd_float4> damage_rects_;
    std::vector<simd_float4> previous_damage_;
    
    // Shader library
    id<MTLLibrary> shader_library_;
    
    // Build shaders
    void buildShaders();
    
    // Build render pipeline
    void buildPipelines();
    
    // Create vertex/index buffers
    void createBuffers();
    
    // Generate geometry for primitives
    void generateRect(const simd_float4& rect, float radius, uint32_t color);
    void generateText(const TextRun& run);
    void generateImage(const simd_float4& rect, const simd_float4& tex_coords);
    
    // Bin commands to tiles
    void binCommandsToTiles();
    
    // Submit render commands
    void submitCommands(id<MTLCommandBuffer> command_buffer, id<MTLRenderCommandEncoder> encoder);
    
    // Composite layers
    void compositeLayers(id<MTLCommandBuffer> command_buffer);
    
public:
    RenderEngine();
    
    // Initialize with Metal device
    void initialize(id<MTLDevice> device, CAMetalLayer* layer);
    
    // Begin frame
    void beginFrame();
    
    // End frame and present
    void endFrame();
    
    // Render layout tree
    void renderLayoutTree(Layout::LayoutNode* root, const simd_float4& viewport);
    
    // Submit render command
    void submit(const RenderCommand& cmd);
    
    // Create composited layer
    uint32_t createLayer(const simd_float4& bounds, bool opaque = false);
    
    // Update layer transform (animation-friendly)
    void updateLayerTransform(uint32_t layer_id, const simd_float4x4& transform);
    
    // Update layer opacity
    void updateLayerOpacity(uint32_t layer_id, float opacity);
    
    // Damage rect for incremental rendering
    void addDamageRect(const simd_float4& rect);
    
    // Clear damage
    void clearDamage();
    
    // Render text
    void renderText(const TextRun& run);
    
    // Render rectangle
    void renderRect(const simd_float4& rect, float radius, simd_float4 color, float opacity = 1.0f);
    
    // Render image
    void renderImage(id<MTLTexture> texture, const simd_float4& rect, const simd_float4& tex_coords);
    
    // Set transform matrix
    void setTransform(const simd_float4x4& matrix);
    
    // Set clip rect
    void setClipRect(const simd_float4& rect);
    
    // Get statistics
    const Stats& stats() const { return stats_; }
    
    // Wait for GPU idle
    void waitForGPU();
    
private:
    Stats stats_;
};

// GPU-accelerated effects
class EffectEngine {
public:
    // Blur effect with compute shader
    void blur(id<MTLTexture> source, id<MTLTexture> dest, float radius);
    
    // Drop shadow
    void shadow(id<MTLTexture> source, id<MTLTexture> dest, 
               float offset_x, float offset_y, float blur, simd_float4 color);
    
    // Color matrix (brightness, contrast, saturation)
    void colorMatrix(id<MTLTexture> source, id<MTLTexture> dest, const float matrix[20]);
    
    // Blend modes
    void blend(id<MTLTexture> bottom, id<MTLTexture> top, 
              id<MTLTexture> dest, uint32_t blend_mode);
};

} // namespace Render

} // namespace Vortex
