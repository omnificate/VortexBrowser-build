#pragma once
#include "CSS.h"
#include <simd/simd.h>
#include <vector>
#include <memory>

namespace Vortex {

struct LayoutBox {
    simd_float2 position;
    simd_float2 size;
    simd_float2 content_size;
    float baseline;
    DOMNodePtr node;
    std::vector<std::shared_ptr<LayoutBox>> children;
    
    // Margin, border, padding
    simd_float4 margin;    // top, right, bottom, left
    simd_float4 border;
    simd_float4 padding;
    
    LayoutBox() 
        : position(simd_make_float2(0, 0))
        , size(simd_make_float2(0, 0))
        , content_size(simd_make_float2(0, 0))
        , baseline(0)
        , margin(simd_make_float4(0, 0, 0, 0))
        , border(simd_make_float4(0, 0, 0, 0))
        , padding(simd_make_float4(0, 0, 0, 0))
    {}
};

class LayoutEngine {
public:
    std::shared_ptr<LayoutBox> buildLayoutTree(const DOMNodePtr& root);
    void performLayout(const std::shared_ptr<LayoutBox>& root, float available_width);
    
    void computeWidths(const std::shared_ptr<LayoutBox>& box, float parent_width);
    void computeHeights(const std::shared_ptr<LayoutBox>& box);
    simd_float2 positionBox(const std::shared_ptr<LayoutBox>& box, simd_float2 parent_pos);
    
    // SIMD-accelerated layout
    void layoutFlexContainer(const std::shared_ptr<LayoutBox>& flex_container);
    void layoutGridContainer(const std::shared_ptr<LayoutBox>& grid_container);
    
    // Text measurement
    float measureText(const std::string& text, float font_size, const std::string& font_family);
    simd_float2 measureTextSIMD(const std::string& text, float font_size);
    
    void reflow(const std::shared_ptr<LayoutBox>& changed_box);
    
private:
    StyleEngine* style_engine_;
    
    void layoutBlockChildren(const std::shared_ptr<LayoutBox>& parent);
    void layoutInlineChildren(const std::shared_ptr<LayoutBox>& parent);
    void resolveMargins(const std::shared_ptr<LayoutBox>& box, float parent_width);
};

} // namespace Vortex
