#pragma once

#include "Core.h"
#include "HTMLParser.h"
#include "CSS.h"
#include <simd/simd.h>
#include <Metal/Metal.h>

namespace Vortex {

// SLayout - SIMD-Accelerated Layout Engine
// Computes layout at 60+ fps for complex documents

namespace Layout {

// Box model - using SIMD for parallel computation
struct LayoutBox {
    // Content box
    float content_x, content_y;
    float content_width, content_height;
    
    // Padding
    float padding_top, padding_right, padding_bottom, padding_left;
    
    // Border
    float border_top, border_right, border_bottom, float border_left;
    
    // Margin
    float margin_top, margin_right, margin_bottom, margin_left;
    
    // Computed box using SIMD
    simd_float4 getContentRect() const {
        return simd_make_float4(content_x, content_y, content_width, content_height);
    }
    
    simd_float4 getPaddingRect() const {
        return simd_make_float4(
            content_x - padding_left,
            content_y - padding_top,
            content_width + padding_left + padding_right,
            content_height + padding_top + padding_bottom
        );
    }
    
    simd_float4 getBorderRect() const {
        return simd_make_float4(
            content_x - padding_left - border_left,
            content_y - padding_top - border_top,
            content_width + padding_left + padding_right + border_left + border_right,
            content_height + padding_top + padding_bottom + border_top + border_bottom
        );
    }
    
    simd_float4 getMarginRect() const {
        return simd_make_float4(
            content_x - padding_left - border_left - margin_left,
            content_y - padding_top - border_top - margin_top,
            content_width + padding_left + padding_right + border_left + border_right + margin_left + margin_right,
            content_height + padding_top + padding_bottom + border_top + border_bottom + margin_top + margin_bottom
        );
    }
    
    // SIMD batch operations
    static void computeWidthsSIMD(LayoutBox* boxes, size_t count, float available_width);
    static void computeHeightsSIMD(LayoutBox* boxes, size_t count);
};

// Layout tree node - lock-free construction
struct LayoutNode {
    HTMLParser::DOMBuilder::Node* dom_node;
    
    LayoutBox box;
    CSS::ComputedStyle style;
    
    // Tree structure
    std::atomic<LayoutNode*> parent{nullptr};
    std::atomic<LayoutNode*> first_child{nullptr};
    std::atomic<LayoutNode*> next_sibling{nullptr};
    
    // Layout state
    enum LayoutState {
        CLEAN,
        DIRTY,
        CHILDREN_DIRTY
    };
    std::atomic<LayoutState> state{CLEAN};
    
    // Layer for compositing
    uint32_t layer_id;
    bool needs_layer;
    
    // Text content (for text nodes)
    SIMDString text_content;
    std::vector<float> glyph_positions;  // X positions for each glyph
    std::vector<float> glyph_advances;     // Advance widths
    
    // Fast insertion
    void appendChild(LayoutNode* child);
    void removeChild(LayoutNode* child);
    
    // Memory pool
    static LockFreePool<LayoutNode, 1024> pool;
    void* operator new(size_t) { return pool.allocate(); }
    void operator delete(void*) { /* pool-managed */ }
};

// Layout algorithm types
enum LayoutAlgorithm {
    BLOCK_FLOW,    // Block layout
    INLINE_FLOW,   // Inline layout
    FLEX,          // Flexbox
    GRID,          // CSS Grid
    TABLE,         // Table layout
    ABSOLUTE,      // Absolute positioning
    FIXED          // Fixed positioning
};

// Block layout algorithm
class BlockLayout {
public:
    // Layout children in block flow
    void layout(LayoutNode* container, float available_width);
    
    // SIMD-parallel margin collapsing
    void collapseMarginsSIMD(LayoutNode* first, LayoutNode* second);
};

// Flexbox layout algorithm - SIMD optimized
class FlexLayout {
public:
    struct FlexItem {
        LayoutNode* node;
        float flex_grow;
        float flex_shrink;
        float flex_basis;
        float target_main_size;
        float target_cross_size;
    };
    
    struct FlexLine {
        std::vector<FlexItem> items;
        float cross_size;
    };
    
    void layout(LayoutNode* container, float available_width, float available_height);
    
private:
    // SIMD-parallel flex item sizing
    void computeFlexBasisSIMD(std::vector<FlexItem>& items);
    void resolveFlexibleLengthsSIMD(std::vector<FlexItem>& items, float available_space);
    void alignItemsSIMD(std::vector<FlexLine>& lines);
};

// Inline layout algorithm with GPU text shaping
class InlineLayout {
public:
    struct LineBox {
        float x, y;
        float width, height;
        std::vector<LayoutNode*> inline_items;
    };
    
    void layout(LayoutNode* container, float available_width);
    
    // GPU-accelerated text shaping
    void shapeTextGPU(LayoutNode* text_node);
    
    // SIMD line breaking
    std::vector<LineBox> breakLinesSIMD(const std::vector<LayoutNode*>& inline_items,
                                       float available_width);
};

// Main layout engine
class LayoutEngine {
public:
    struct Constraints {
        float available_width;
        float available_height;
        float min_width;
        float min_height;
        bool width_defined;
        bool height_defined;
    };
    
    struct LayoutResult {
        float min_content_width;
        float max_content_width;
        float preferred_width;
        float preferred_height;
    };
    
private:
    // Work queue for parallel layout
    struct LayoutTask {
        LayoutNode* node;
        Constraints constraints;
    };
    
    std::vector<LayoutTask> work_queue_;
    std::atomic<bool> has_work_{false};
    
    // Algorithm instances
    BlockLayout block_layout_;
    FlexLayout flex_layout_;
    InlineLayout inline_layout_;
    
    // Create layout tree from DOM
    LayoutNode* createLayoutTree(HTMLParser::DOMBuilder::Node* dom_node);
    
    // Determine layout algorithm
    LayoutAlgorithm determineAlgorithm(const CSS::ComputedStyle& style);
    
    // Compute layout for a node
    void computeLayout(LayoutNode* node, const Constraints& constraints);
    
    // Parallel layout using work stealing
    void processWorkQueue();
    
public:
    LayoutEngine();
    
    // Full document layout
    void layoutDocument(HTMLParser::DOMBuilder::Node* root,
                       float viewport_width,
                       float viewport_height);
    
    // Incremental layout - only recompute changed nodes
    void updateLayout(LayoutNode* changed_node);
    
    // Layout tree access
    LayoutNode* root() const { return root_; }
    
    // Hit testing
    LayoutNode* hitTest(float x, float y);
    
    // Get layout tree
    LayoutNode* getLayoutTree() const { return root_; }
    
private:
    LayoutNode* root_;
};

// Layout cache for incremental updates
class LayoutCache {
public:
    struct CacheEntry {
        uint64_t node_id;
        Constraints constraints;
        LayoutBox computed_box;
        std::atomic<bool> valid{true};
    };
    
    // Get cached layout if valid
    bool get(HTMLParser::DOMBuilder::Node* node,
            const Constraints& constraints,
            LayoutBox& out_box);
    
    // Store computed layout
    void put(HTMLParser::DOMBuilder::Node* node,
            const Constraints& constraints,
            const LayoutBox& box);
    
    // Invalidate cache for node and descendants
    void invalidate(HTMLParser::DOMBuilder::Node* node);
    
private:
    static constexpr size_t CACHE_SIZE = 8192;
    CacheEntry entries_[CACHE_SIZE];
    
    size_t hash(uint64_t node_id, float width) const {
        return (node_id ^ (uint64_t)(width * 1000)) % CACHE_SIZE;
    }
};

// Scroll optimization
class ScrollOptimizer {
public:
    struct ScrollContainer {
        LayoutNode* node;
        float scroll_x, scroll_y;
        float content_width, content_height;
        float viewport_width, viewport_height;
        
        // Visible area for culling
        simd_float4 visible_rect;
    };
    
    // Update scroll position
    void updateScroll(ScrollContainer* container, float dx, float dy);
    
    // Get visible nodes (culling)
    std::vector<LayoutNode*> getVisibleNodes(ScrollContainer* container);
    
    // Predict scroll momentum
    float predictScrollPosition(float velocity, float deceleration);
};

} // namespace Layout

} // namespace Vortex
