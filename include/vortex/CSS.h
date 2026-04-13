#pragma once

#include "Core.h"
#include <vector>
#include <simd/simd.h>

namespace Vortex {

// CSS value types using SIMD-friendly storage
namespace CSS {

// Value types
enum ValueType {
    NUMBER,
    PERCENTAGE,
    LENGTH,
    COLOR,
    STRING,
    IDENT,
    URL,
    LIST,
    AUTO,
    NONE
};

// Length units
enum LengthUnit {
    PX,
    EM,
    REM,
    VW,
    VH,
    PT,
    PERCENT
};

// SIMD-aligned color value (RGBA)
struct Color {
    union {
        struct { float r, g, b, a; };
        simd_float4 vec;
    };
    
    Color() : vec(simd_make_float4(0, 0, 0, 1)) {}
    Color(float r_, float g_, float b_, float a_ = 1.0f) 
        : vec(simd_make_float4(r_, g_, b_, a_)) {}
    
    static Color parse(const char* str);
    static Color parseHex(const char* hex);
    
    // SIMD blend
    Color blend(const Color& other, float t) const {
        return Color(simd_mix(vec, other.vec, simd_make_float4(t, t, t, t)));
    }
};

// Length value with SIMD acceleration
struct Length {
    float value;
    LengthUnit unit;
    
    float toPixels(float base_size = 16.0f, float viewport_width = 0, float viewport_height = 0) const;
};

// Generic CSS value
struct Value {
    ValueType type;
    union {
        float number;
        Length length;
        Color color;
    };
    SIMDString string_value;
    std::vector<Value> list_values;
    
    Value() : type(NONE), number(0) {}
    explicit Value(float n) : type(NUMBER), number(n) {}
    explicit Value(const Color& c) : type(COLOR) { color = c; }
    explicit Value(const Length& l) : type(LENGTH) { length = l; }
    
    bool operator==(const Value& other) const;
};

// Property ID for fast lookup
enum PropertyID : uint16_t {
    // Layout
    PROP_DISPLAY,
    PROP_POSITION,
    PROP_TOP,
    PROP_RIGHT,
    PROP_BOTTOM,
    PROP_LEFT,
    PROP_WIDTH,
    PROP_HEIGHT,
    PROP_MIN_WIDTH,
    PROP_MIN_HEIGHT,
    PROP_MAX_WIDTH,
    PROP_MAX_HEIGHT,
    PROP_MARGIN_TOP,
    PROP_MARGIN_RIGHT,
    PROP_MARGIN_BOTTOM,
    PROP_MARGIN_LEFT,
    PROP_PADDING_TOP,
    PROP_PADDING_RIGHT,
    PROP_PADDING_BOTTOM,
    PROP_PADDING_LEFT,
    PROP_BORDER_TOP_WIDTH,
    PROP_BORDER_RIGHT_WIDTH,
    PROP_BORDER_BOTTOM_WIDTH,
    PROP_BORDER_LEFT_WIDTH,
    
    // Flexbox
    PROP_FLEX_DIRECTION,
    PROP_FLEX_WRAP,
    PROP_JUSTIFY_CONTENT,
    PROP_ALIGN_ITEMS,
    PROP_ALIGN_CONTENT,
    PROP_FLEX_GROW,
    PROP_FLEX_SHRINK,
    PROP_FLEX_BASIS,
    
    // Visual
    PROP_BACKGROUND_COLOR,
    PROP_BACKGROUND_IMAGE,
    PROP_OPACITY,
    PROP_VISIBILITY,
    PROP_OVERFLOW,
    PROP_Z_INDEX,
    
    // Text
    PROP_FONT_SIZE,
    PROP_FONT_FAMILY,
    PROP_FONT_WEIGHT,
    PROP_FONT_STYLE,
    PROP_TEXT_ALIGN,
    PROP_LINE_HEIGHT,
    PROP_COLOR,
    PROP_TEXT_DECORATION,
    PROP_WHITE_SPACE,
    
    // Transform
    PROP_TRANSFORM,
    PROP_TRANSFORM_ORIGIN,
    
    // Animation
    PROP_TRANSITION,
    PROP_ANIMATION,
    PROP_ANIMATION_NAME,
    PROP_ANIMATION_DURATION,
    PROP_ANIMATION_TIMING_FUNCTION,
    PROP_ANIMATION_DELAY,
    PROP_ANIMATION_ITERATION_COUNT,
    PROP_ANIMATION_DIRECTION,
    
    // Custom properties
    PROP_CUSTOM_START = 1000,
    PROP_MAX = 65535
};

// Property name to ID mapping
PropertyID propertyNameToID(const SIMDString& name);

// Computed style for a node
struct ComputedStyle {
    // Layout properties
    Value display;
    Value position;
    Value top, right, bottom, left;
    Value width, height;
    Value margin[4];  // top, right, bottom, left
    Value padding[4];
    Value border_width[4];
    
    // Flexbox
    Value flex_direction;
    Value flex_wrap;
    Value justify_content;
    Value align_items;
    Value align_content;
    Value flex_grow;
    Value flex_shrink;
    Value flex_basis;
    
    // Visual
    Value background_color;
    Value opacity;
    Value visibility;
    Value overflow;
    Value z_index;
    
    // Text
    Value font_size;
    Value font_family;
    Value font_weight;
    Value text_align;
    Value line_height;
    Value color;
    
    // Animation state
    float animation_progress[16];
    
    // SIMD-friendly storage for fast comparison
    bool operator==(const ComputedStyle& other) const;
    bool operator!=(const ComputedStyle& other) const { return !(*this == other); }
};

} // namespace CSS

// Parallel CSS style engine
class StyleEngine {
public:
    // Style rule
    struct Rule {
        // Selector string (compiled to bytecode for fast matching)
        SIMDString selector_string;
        
        // Compiled selector bytecode for SIMD matching
        struct SelectorBytecode {
            enum Opcode {
                TAG,           // Match tag name
                CLASS,         // Match class
                ID,            // Match ID
                ATTR,          // Match attribute
                PSEUDO,        // Match pseudo-class
                DESCENDANT,    // Space combinator
                CHILD,         // > combinator
                ADJACENT,      // + combinator
                SIBLING,       // ~ combinator
                END
            };
            
            struct Instruction {
                Opcode op;
                uint32_t arg;  // Index into string table
            };
            
            std::vector<Instruction> instructions;
            std::vector<SIMDString> strings;
        } bytecode;
        
        // Declarations
        std::vector<std::pair<CSS::PropertyID, CSS::Value>> declarations;
        
        // Specificity for cascade
        uint32_t specificity;
        
        // Source order
        uint32_t order;
    };
    
    // Stylesheet
    struct Stylesheet {
        std::vector<Rule> rules;
        ConcurrentHashMap<SIMDString, CSS::Value, 256> custom_properties;
    };
    
private:
    std::vector<Stylesheet> stylesheets_;
    
    // Matched declarations cache (MDC) - maps element+property to computed value
    struct CacheKey {
        uint64_t node_id;
        CSS::PropertyID property;
        
        bool operator==(const CacheKey& other) const {
            return node_id == other.node_id && property == other.property;
        }
    };
    
    struct CacheKeyHash {
        uint64_t operator()(const CacheKey& key) const {
            return key.node_id ^ (static_cast<uint64_t>(key.property) << 32);
        }
    };
    
    // Lock-free LRU cache
    std::unordered_map<CacheKey, CSS::Value, CacheKeyHash> mdc_;
    
    // Compile selector to bytecode
    void compileSelector(Rule& rule);
    
    // SIMD-accelerated selector matching
    bool matchSelectorSIMD(const Rule::SelectorBytecode& bytecode, 
                          HTMLParser::DOMBuilder::Node* node);
    
    // Parallel style computation using work queues
    void computeStylesParallel(std::vector<HTMLParser::DOMBuilder::Node*>& nodes);
    
public:
    void addStylesheet(const Stylesheet& sheet);
    
    // Parse CSS text
    Stylesheet parseCSS(const char* css, size_t len);
    
    // Compute styles for all nodes
    void computeStyles(HTMLParser::DOMBuilder::Node* root);
    
    // Get computed style for a node
    CSS::ComputedStyle getComputedStyle(HTMLParser::DOMBuilder::Node* node);
    
    // Update styles incrementally
    void updateStyles(HTMLParser::DOMBuilder::Node* changed_node);
};

// Custom property (CSS variable) resolver
class CustomPropertyResolver {
public:
    CSS::Value resolve(const SIMDString& name, 
                      HTMLParser::DOMBuilder::Node* node,
                      const std::vector<StyleEngine::Stylesheet>& stylesheets);
};

// Animation engine
class AnimationEngine {
public:
    struct Animation {
        SIMDString name;
        float duration;      // seconds
        float delay;         // seconds
        int iteration_count;
        bool alternate;
        
        // Keyframes
        struct Keyframe {
            float offset;  // 0.0 to 1.0
            CSS::ComputedStyle style;
        };
        std::vector<Keyframe> keyframes;
        
        // Current state
        float current_time;
        bool running;
        bool paused;
    };
    
private:
    std::vector<Animation> animations_;
    
    // Interpolate between keyframes
    CSS::Value interpolate(const CSS::Value& from, const CSS::Value& to, float t);
    
public:
    void addAnimation(const Animation& anim);
    void removeAnimation(const SIMDString& name);
    
    // Tick animation by delta time
    void tick(float delta_time);
    
    // Apply animations to computed styles
    void applyAnimations(HTMLParser::DOMBuilder::Node* root);
};

} // namespace Vortex
