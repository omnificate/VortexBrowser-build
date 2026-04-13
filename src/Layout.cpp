#include "vortex/Layout.h"
#include "vortex/CSS.h"
#include <simd/simd.h>
#include <algorithm>
#include <cmath>

namespace Vortex {

std::shared_ptr<LayoutBox> LayoutEngine::buildLayoutTree(const DOMNodePtr& root) {
    if (!root) return nullptr;
    
    auto box = std::make_shared<LayoutBox>();
    box->node = root;
    
    for (auto& child : root->children) {
        auto child_box = buildLayoutTree(child);
        if (child_box) {
            box->children.push_back(child_box);
        }
    }
    
    return box;
}

void LayoutEngine::performLayout(const std::shared_ptr<LayoutBox>& root, float available_width) {
    if (!root) return;
    
    computeWidths(root, available_width);
    computeHeights(root);
    positionBox(root, simd_make_float2(0, 0));
}

void LayoutEngine::computeWidths(const std::shared_ptr<LayoutBox>& box, float parent_width) {
    if (!box || !box->node) return;
    
    // Get computed style
    // Would get from style engine in real implementation
    
    // Default to full width minus margins
    float margin_left = box->margin[3];
    float margin_right = box->margin[1];
    float padding_left = box->padding[3];
    float padding_right = box->padding[1];
    
    float available_width = parent_width - margin_left - margin_right - padding_left - padding_right;
    
    box->size.x = available_width;
    box->content_size.x = available_width - padding_left - padding_right;
    
    // Recurse into children
    for (auto& child : box->children) {
        computeWidths(child, box->content_size.x);
    }
}

void LayoutEngine::computeHeights(const std::shared_ptr<LayoutBox>& box) {
    if (!box) return;
    
    float total_height = 0;
    
    for (auto& child : box->children) {
        computeHeights(child);
        total_height += child->size.y + child->margin[0] + child->margin[2];
    }
    
    float padding_top = box->padding[0];
    float padding_bottom = box->padding[2];
    
    box->content_size.y = total_height;
    box->size.y = total_height + padding_top + padding_bottom;
}

simd_float2 LayoutEngine::positionBox(const std::shared_ptr<LayoutBox>& box, simd_float2 parent_pos) {
    if (!box) return parent_pos;
    
    float margin_left = box->margin[3];
    float margin_top = box->margin[0];
    
    box->position = simd_make_float2(
        parent_pos.x + margin_left,
        parent_pos.y + margin_top
    );
    
    simd_float2 child_pos = simd_make_float2(
        box->position.x + box->padding[3],
        box->position.y + box->padding[0]
    );
    
    for (auto& child : box->children) {
        positionBox(child, child_pos);
        child_pos.y += child->size.y + child->margin[0] + child->margin[2];
    }
    
    return box->position;
}

void LayoutEngine::layoutBlockChildren(const std::shared_ptr<LayoutBox>& parent) {
    if (!parent) return;
    
    float y_offset = parent->padding[0];
    
    for (auto& child : parent->children) {
        child->position.y = y_offset;
        y_offset += child->size.y + child->margin[0] + child->margin[2];
    }
}

void LayoutEngine::layoutInlineChildren(const std::shared_ptr<LayoutBox>& parent) {
    if (!parent) return;
    
    float x_offset = parent->padding[3];
    float y_offset = parent->padding[0];
    float line_height = 0;
    
    for (auto& child : parent->children) {
        if (x_offset + child->size.x > parent->content_size.x) {
            x_offset = parent->padding[3];
            y_offset += line_height;
            line_height = 0;
        }
        
        child->position.x = x_offset;
        child->position.y = y_offset;
        x_offset += child->size.x;
        line_height = std::max(line_height, child->size.y);
    }
}

void LayoutEngine::layoutFlexContainer(const std::shared_ptr<LayoutBox>& flex_container) {
    if (!flex_container) return;
    
    // Simple flex layout - just stack horizontally
    float x_offset = flex_container->padding[3];
    float available_height = flex_container->content_size.y;
    
    for (auto& child : flex_container->children) {
        child->position.x = x_offset;
        child->position.y = flex_container->padding[0];
        x_offset += child->size.x + child->margin[1] + child->margin[3];
    }
}

void LayoutEngine::layoutGridContainer(const std::shared_ptr<LayoutBox>& grid_container) {
    if (!grid_container) return;
    
    // Simple grid layout
    int cols = 3; // Would parse from CSS
    float col_width = grid_container->content_size.x / cols;
    
    for (size_t i = 0; i < grid_container->children.size(); ++i) {
        auto& child = grid_container->children[i];
        int col = i % cols;
        int row = i / cols;
        
        child->position.x = grid_container->padding[3] + col * col_width;
        child->position.y = grid_container->padding[0] + row * 100; // Row height
    }
}

float LayoutEngine::measureText(const std::string& text, float font_size, const std::string& font_family) {
    // Approximation: ~0.6em per character on average
    return text.length() * font_size * 0.6f;
}

simd_float2 LayoutEngine::measureTextSIMD(const std::string& text, float font_size) {
    float width = text.length() * font_size * 0.6f;
    float height = font_size * 1.2f; // Line height
    return simd_make_float2(width, height);
}

void LayoutEngine::reflow(const std::shared_ptr<LayoutBox>& changed_box) {
    // Mark layout as needing recalculation
    // Would trigger incremental layout in real implementation
}

void LayoutEngine::resolveMargins(const std::shared_ptr<LayoutBox>& box, float parent_width) {
    // Resolve percentage margins
    // Would parse from CSS in real implementation
}

} // namespace Vortex
