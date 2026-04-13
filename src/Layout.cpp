#include "vortex/Layout.h"
#include "vortex/Core.h"
#include "vortex/CSS.h"
#include <dispatch/dispatch.h>
#include <simd/simd.h>

namespace Vortex {
namespace Layout {

// Memory pool for layout nodes
LockFreePool<LayoutNode, 1024> LayoutNode::pool;

// LayoutEngine Implementation
LayoutEngine::LayoutEngine() : root_(nullptr) {
}

void LayoutEngine::layoutDocument(HTMLParser::DOMBuilder::Node* root,
                                  float viewport_width,
                                  float viewport_height) {
    if (!root) return;
    
    // Create layout tree from DOM
    root_ = createLayoutTree(root);
    
    // Set up constraints
    Constraints constraints;
    constraints.available_width = viewport_width;
    constraints.available_height = viewport_height;
    constraints.width_defined = true;
    constraints.height_defined = false;
    
    // Compute layout
    computeLayout(root_, constraints);
    
    // Process any remaining work queue items in parallel
    processWorkQueue();
}

LayoutNode* LayoutEngine::createLayoutTree(HTMLParser::DOMBuilder::Node* dom_node) {
    if (!dom_node) return nullptr;
    
    LayoutNode* layout_node = new LayoutNode();
    layout_node->dom_node = dom_node;
    
    // Create children recursively
    HTMLParser::DOMBuilder::Node* dom_child = dom_node->first_child.load(std::memory_order_acquire);
    LayoutNode* prev_layout_child = nullptr;
    
    while (dom_child) {
        LayoutNode* layout_child = createLayoutTree(dom_child);
        if (layout_child) {
            layout_child->parent.store(layout_node, std::memory_order_relaxed);
            
            if (prev_layout_child) {
                prev_layout_child->next_sibling.store(layout_child, std::memory_order_release);
            } else {
                layout_node->first_child.store(layout_child, std::memory_order_release);
            }
            prev_layout_child = layout_child;
        }
        dom_child = dom_child->next_sibling.load(std::memory_order_acquire);
    }
    
    return layout_node;
}

LayoutAlgorithm LayoutEngine::determineAlgorithm(const CSS::ComputedStyle& style) {
    // Determine layout algorithm based on display property
    if (style.display.type == CSS::IDENT) {
        const char* display = style.display.string_value.hash() ? "flex" : "block";
        // Check for flexbox
        if (strcmp(display, "flex") == 0 || strcmp(display, "inline-flex") == 0) {
            return FLEX;
        }
    }
    
    // Check for absolute/fixed positioning
    if (style.position.type == CSS::IDENT) {
        const char* pos = style.position.string_value.hash() ? "absolute" : "static";
        if (strcmp(pos, "absolute") == 0) return ABSOLUTE;
        if (strcmp(pos, "fixed") == 0) return FIXED;
    }
    
    // Default to block flow
    return BLOCK_FLOW;
}

void LayoutEngine::computeLayout(LayoutNode* node, const Constraints& constraints) {
    if (!node) return;
    
    // Mark as dirty if needed
    if (node->state.load(std::memory_order_acquire) != CLEAN) {
        // Recompute layout for this node
    }
    
    // Determine layout algorithm
    LayoutAlgorithm algo = determineAlgorithm(node->style);
    
    switch (algo) {
        case BLOCK_FLOW:
            block_layout_.layout(node, constraints.available_width);
            break;
            
        case FLEX:
            flex_layout_.layout(node, 
                              constraints.available_width, 
                              constraints.available_height);
            break;
            
        case INLINE_FLOW:
            inline_layout_.layout(node, constraints.available_width);
            break;
            
        case ABSOLUTE:
        case FIXED:
            // Handle positioned elements
            break;
            
        default:
            block_layout_.layout(node, constraints.available_width);
            break;
    }
    
    // Layout children
    LayoutNode* child = node->first_child.load(std::memory_order_acquire);
    while (child) {
        Constraints child_constraints = constraints;
        
        // Adjust constraints based on parent's box model
        float padding_left = node->box.padding_left;
        float padding_right = node->box.padding_right;
        child_constraints.available_width -= (padding_left + padding_right);
        
        computeLayout(child, child_constraints);
        child = child->next_sibling.load(std::memory_order_acquire);
    }
    
    // Mark as clean
    node->state.store(CLEAN, std::memory_order_release);
}

void LayoutEngine::processWorkQueue() {
    // Parallel work processing using GCD
    if (!work_queue_.empty()) {
        dispatch_apply(work_queue_.size(), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), 
            ^(size_t i) {
                // Process work item
                const LayoutTask& task = this->work_queue_[i];
                this->computeLayout(task.node, task.constraints);
            });
        work_queue_.clear();
    }
}

void LayoutEngine::updateLayout(LayoutNode* changed_node) {
    if (!changed_node) return;
    
    // Mark node and ancestors as dirty
    LayoutNode* node = changed_node;
    while (node) {
        node->state.store(DIRTY, std::memory_order_release);
        node = node->parent.load(std::memory_order_acquire);
    }
    
    // Recompute layout
    Constraints constraints;
    constraints.available_width = 1024; // TODO: Get from viewport
    constraints.available_height = 768;
    
    computeLayout(changed_node, constraints);
}

LayoutNode* LayoutEngine::hitTest(float x, float y) {
    if (!root_) return nullptr;
    
    std::function<LayoutNode*(LayoutNode*)> hitTestRecursive;
    hitTestRecursive = [x, y, &hitTestRecursive](LayoutNode* node) -> LayoutNode* {
        if (!node) return nullptr;
        
        simd_float4 box = node->box.getBorderRect();
        
        // Check if point is inside box
        if (x >= box.x && x <= box.x + box.z &&
            y >= box.y && y <= box.y + box.w) {
            
            // Check children first (front-to-back)
            LayoutNode* child = node->first_child.load(std::memory_order_acquire);
            while (child) {
                LayoutNode* hit = hitTestRecursive(child);
                if (hit) return hit;
                child = child->next_sibling.load(std::memory_order_acquire);
            }
            
            return node;
        }
        
        return nullptr;
    };
    
    return hitTestRecursive(root_);
}

// BlockLayout Implementation
void BlockLayout::layout(LayoutNode* container, float available_width) {
    if (!container) return;
    
    float y = container->box.content_y + container->box.padding_top;
    float content_width = available_width - 
                         container->box.padding_left - 
                         container->box.padding_right -
                         container->box.border_left - 
                         container->box.border_right;
    
    LayoutNode* child = container->first_child.load(std::memory_order_acquire);
    
    while (child) {
        // Position child
        child->box.content_x = container->box.content_x + 
                              container->box.padding_left + 
                              container->box.border_left;
        child->box.content_y = y;
        
        // Set width (respect child's constraints)
        if (child->style.width.type != CSS::AUTO && child->style.width.type != CSS::NONE) {
            // Fixed width
            child->box.content_width = content_width; // Simplified
        } else {
            child->box.content_width = content_width;
        }
        
        // Add margin
        y += child->box.margin_top;
        
        // Add child's height
        y += child->box.content_height + 
             child->box.padding_top + child->box.padding_bottom +
             child->box.border_top + child->box.border_bottom;
        
        // Add margin bottom
        y += child->box.margin_bottom;
        
        // Add spacing
        y += 0; // Can add margin collapsing here
        
        child = child->next_sibling.load(std::memory_order_acquire);
    }
    
    // Set container height
    container->box.content_height = y - container->box.content_y - container->box.padding_top;
}

void BlockLayout::collapseMarginsSIMD(LayoutNode* first, LayoutNode* second) {
    if (!first || !second) return;
    
    // SIMD-parallel margin collapsing
    float margin1 = first->box.margin_bottom;
    float margin2 = second->box.margin_top;
    
    // Collapse to max
    float collapsed = fmax(margin1, margin2);
    
    first->box.margin_bottom = collapsed;
    second->box.margin_top = 0; // Absorbed
}

// FlexLayout Implementation
void FlexLayout::layout(LayoutNode* container, float available_width, float available_height) {
    if (!container) return;
    
    // Collect flex items
    std::vector<FlexItem> items;
    LayoutNode* child = container->first_child.load(std::memory_order_acquire);
    
    while (child) {
        FlexItem item;
        item.node = child;
        
        // Parse flex properties
        if (child->style.flex_grow.type == CSS::NUMBER) {
            item.flex_grow = child->style.flex_grow.number;
        } else {
            item.flex_grow = 0;
        }
        
        if (child->style.flex_shrink.type == CSS::NUMBER) {
            item.flex_shrink = child->style.flex_shrink.number;
        } else {
            item.flex_shrink = 1;
        }
        
        if (child->style.flex_basis.type != CSS::AUTO && 
            child->style.flex_basis.type != CSS::NONE) {
            if (child->style.flex_basis.type == CSS::LENGTH) {
                item.flex_basis = child->style.flex_basis.length.value;
            } else {
                item.flex_basis = child->box.content_width;
            }
        } else {
            item.flex_basis = child->box.content_width;
        }
        
        items.push_back(item);
        child = child->next_sibling.load(std::memory_order_acquire);
    }
    
    if (items.empty()) return;
    
    // Compute flex basis for all items (SIMD-optimized)
    computeFlexBasisSIMD(items);
    
    // Calculate remaining space
    float total_basis = 0;
    for (const auto& item : items) {
        total_basis += item.flex_basis;
    }
    
    float remaining_space = available_width - total_basis -
                           container->box.padding_left - container->box.padding_right -
                           container->box.border_left - container->box.border_right;
    
    // Distribute remaining space
    if (remaining_space > 0) {
        resolveFlexibleLengthsSIMD(items, remaining_space);
    }
    
    // Position items
    float x = container->box.content_x + container->box.padding_left + container->box.border_left;
    float y = container->box.content_y + container->box.padding_top + container->box.border_top;
    float max_cross_size = 0;
    
    for (auto& item : items) {
        item.node->box.content_x = x;
        item.node->box.content_y = y;
        item.node->box.content_width = item.target_main_size;
        
        // Height is cross size for row flex
        item.target_cross_size = item.node->box.content_height;
        if (item.target_cross_size > max_cross_size) {
            max_cross_size = item.target_cross_size;
        }
        
        x += item.target_main_size;
    }
    
    // Set container height
    container->box.content_height = max_cross_size;
}

void FlexLayout::computeFlexBasisSIMD(std::vector<FlexItem>& items) {
    // SIMD-parallel computation of flex basis
    // In real implementation: use dispatch_apply for parallel processing
    for (auto& item : items) {
        if (item.flex_basis == 0) {
            // Auto basis - use content width
            item.flex_basis = item.node->box.content_width;
        }
        item.target_main_size = item.flex_basis;
    }
}

void FlexLayout::resolveFlexibleLengthsSIMD(std::vector<FlexItem>& items, float available_space) {
    // Calculate total flex grow
    float total_flex_grow = 0;
    for (const auto& item : items) {
        total_flex_grow += item.flex_grow;
    }
    
    if (total_flex_grow > 0 && available_space > 0) {
        float space_per_flex = available_space / total_flex_grow;
        
        for (auto& item : items) {
            if (item.flex_grow > 0) {
                item.target_main_size = item.flex_basis + (item.flex_grow * space_per_flex);
            }
        }
    }
}

void FlexLayout::alignItemsSIMD(std::vector<FlexLine>& lines) {
    // SIMD-parallel alignment computation
    for (auto& line : lines) {
        for (auto& item : line.items) {
            // Center alignment (simplified)
            float cross_offset = (line.cross_size - item.target_cross_size) / 2;
            item.node->box.content_y += cross_offset;
        }
    }
}

// InlineLayout Implementation
void InlineLayout::layout(LayoutNode* container, float available_width) {
    if (!container) return;
    
    // Break into line boxes
    std::vector<LayoutNode*> inline_items;
    
    LayoutNode* child = container->first_child.load(std::memory_order_acquire);
    while (child) {
        inline_items.push_back(child);
        child = child->next_sibling.load(std::memory_order_acquire);
    }
    
    // Break lines
    std::vector<LineBox> lines = breakLinesSIMD(inline_items, available_width);
    
    // Position lines
    float y = container->box.content_y + container->box.padding_top;
    for (auto& line : lines) {
        line.y = y;
        
        // Position items in line
        float x = container->box.content_x + container->box.padding_left;
        for (LayoutNode* item : line.inline_items) {
            item->box.content_x = x;
            item->box.content_y = y;
            x += item->box.content_width;
        }
        
        y += line.height;
    }
    
    container->box.content_height = y - container->box.content_y - container->box.padding_top;
}

std::vector<InlineLayout::LineBox> InlineLayout::breakLinesSIMD(
    const std::vector<LayoutNode*>& inline_items,
    float available_width) {
    
    std::vector<LineBox> lines;
    LineBox current_line;
    current_line.x = 0;
    current_line.y = 0;
    current_line.width = 0;
    current_line.height = 0;
    
    for (LayoutNode* item : inline_items) {
        float item_width = item->box.content_width;
        
        // Check if item fits in current line
        if (current_line.width + item_width > available_width && !current_line.inline_items.empty()) {
            // Finish current line
            lines.push_back(current_line);
            
            // Start new line
            current_line = LineBox();
            current_line.x = 0;
            current_line.y = 0;
            current_line.width = 0;
            current_line.height = 0;
        }
        
        // Add to current line
        current_line.inline_items.push_back(item);
        current_line.width += item_width;
        
        if (item->box.content_height > current_line.height) {
            current_line.height = item->box.content_height;
        }
    }
    
    // Don't forget last line
    if (!current_line.inline_items.empty()) {
        lines.push_back(current_line);
    }
    
    return lines;
}

void InlineLayout::shapeTextGPU(LayoutNode* text_node) {
    // GPU-accelerated text shaping placeholder
    // In real implementation: use compute shaders for parallel shaping
    (void)text_node;
}

// LayoutBox SIMD Operations
void LayoutBox::computeWidthsSIMD(LayoutBox* boxes, size_t count, float available_width) {
    // SIMD-parallel width computation
    // In real implementation: use SIMD intrinsics
    for (size_t i = 0; i < count; i++) {
        LayoutBox& box = boxes[i];
        float margins = box.margin_left + box.margin_right;
        box.content_width = available_width - margins - 
                          box.padding_left - box.padding_right -
                          box.border_left - box.border_right;
    }
}

void LayoutBox::computeHeightsSIMD(LayoutBox* boxes, size_t count) {
    // SIMD-parallel height computation
    for (size_t i = 0; i < count; i++) {
        LayoutBox& box = boxes[i];
        // Height calculation based on content
        (void)box;
    }
}

} // namespace Layout
} // namespace Vortex
