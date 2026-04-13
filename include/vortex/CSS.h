#pragma once
#include "Color.h"
#include <simd/simd.h>
#include <string>
#include <vector>
#include <unordered_map>
#include <memory>

namespace Vortex {

// Forward declaration
struct DOMNode;
using DOMNodePtr = std::shared_ptr<DOMNode>;

enum class DisplayType { BLOCK, INLINE, FLEX, GRID, NONE };
enum class PositionType { STATIC, RELATIVE, ABSOLUTE, FIXED, STICKY };

struct ComputedStyle {
    DisplayType display;
    PositionType position;
    float margin_top, margin_right, margin_bottom, margin_left;
    float padding_top, padding_right, padding_bottom, padding_left;
    float border_width;
    float width, height;
    Color background_color;
    Color text_color;
    float font_size;
    std::string font_family;
    float line_height;
    
    ComputedStyle()
        : display(DisplayType::BLOCK)
        , position(PositionType::STATIC)
        , margin_top(0), margin_right(0), margin_bottom(0), margin_left(0)
        , padding_top(0), padding_right(0), padding_bottom(0), padding_left(0)
        , border_width(0)
        , width(0), height(0)
        , background_color(1, 1, 1, 1)
        , text_color(0, 0, 0, 1)
        , font_size(16)
        , line_height(1.2)
    {}
};

struct CSSProperty {
    std::string name;
    std::string value;
    int specificity;
};

struct CSSRule {
    std::string selector;
    std::vector<CSSProperty> properties;
    int specificity;
};

class CSSParser {
public:
    std::vector<CSSRule> parse(const std::string& css);
    
private:
    size_t pos_;
    
    CSSRule parseRule(const std::string& css);
    std::string parseSelector(const std::string& css);
    CSSProperty parseProperty(const std::string& css);
    void skipWhitespace(const std::string& css);
    void skipComment(const std::string& css);
    int calculateSpecificity(const std::string& selector);
};

class StyleEngine {
public:
    void addRules(const std::vector<CSSRule>& rules);
    void computeStyles(const DOMNodePtr& root);
    void computeStylesParallel(std::vector<DOMNodePtr>& nodes);
    
    ComputedStyle getComputedStyle(const DOMNodePtr& node);
    void updateStyles(const DOMNodePtr& changed_node);
    
    void applyAnimation(const DOMNodePtr& node, const std::string& property, 
                       float start_val, float end_val, float duration);
    void applyAnimations(const DOMNodePtr& root);
    
private:
    std::vector<CSSRule> rules_;
    std::unordered_map<DOMNodePtr, ComputedStyle> computed_styles_;
    
    int calculateSpecificity(const std::string& selector);
    bool matchesSelector(const DOMNodePtr& node, const std::string& selector);
    void cascadeStyles(ComputedStyle& style, const std::vector<CSSProperty>& properties);
};

} // namespace Vortex
