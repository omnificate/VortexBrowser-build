#include "vortex/CSS.h"
#include "vortex/Core.h"
#include <cctype>
#include <cstring>
#include <algorithm>

namespace Vortex {

// Property name to ID mapping table
static struct PropertyMap {
    const char* name;
    CSS::PropertyID id;
} property_map[] = {
    {"display", CSS::PROP_DISPLAY},
    {"position", CSS::PROP_POSITION},
    {"top", CSS::PROP_TOP},
    {"right", CSS::PROP_RIGHT},
    {"bottom", CSS::PROP_BOTTOM},
    {"left", CSS::PROP_LEFT},
    {"width", CSS::PROP_WIDTH},
    {"height", CSS::PROP_HEIGHT},
    {"min-width", CSS::PROP_MIN_WIDTH},
    {"min-height", CSS::PROP_MIN_HEIGHT},
    {"max-width", CSS::PROP_MAX_WIDTH},
    {"max-height", CSS::PROP_MAX_HEIGHT},
    {"margin", CSS::PROP_MARGIN_TOP}, // Shorthand
    {"margin-top", CSS::PROP_MARGIN_TOP},
    {"margin-right", CSS::PROP_MARGIN_RIGHT},
    {"margin-bottom", CSS::PROP_MARGIN_BOTTOM},
    {"margin-left", CSS::PROP_MARGIN_LEFT},
    {"padding", CSS::PROP_PADDING_TOP}, // Shorthand
    {"padding-top", CSS::PROP_PADDING_TOP},
    {"padding-right", CSS::PROP_PADDING_RIGHT},
    {"padding-bottom", CSS::PROP_PADDING_BOTTOM},
    {"padding-left", CSS::PROP_PADDING_LEFT},
    {"border-top-width", CSS::PROP_BORDER_TOP_WIDTH},
    {"border-right-width", CSS::PROP_BORDER_RIGHT_WIDTH},
    {"border-bottom-width", CSS::PROP_BORDER_BOTTOM_WIDTH},
    {"border-left-width", CSS::PROP_BORDER_LEFT_WIDTH},
    {"flex-direction", CSS::PROP_FLEX_DIRECTION},
    {"flex-wrap", CSS::PROP_FLEX_WRAP},
    {"justify-content", CSS::PROP_JUSTIFY_CONTENT},
    {"align-items", CSS::PROP_ALIGN_ITEMS},
    {"align-content", CSS::PROP_ALIGN_CONTENT},
    {"flex-grow", CSS::PROP_FLEX_GROW},
    {"flex-shrink", CSS::PROP_FLEX_SHRINK},
    {"flex-basis", CSS::PROP_FLEX_BASIS},
    {"background-color", CSS::PROP_BACKGROUND_COLOR},
    {"background-image", CSS::PROP_BACKGROUND_IMAGE},
    {"opacity", CSS::PROP_OPACITY},
    {"visibility", CSS::PROP_VISIBILITY},
    {"overflow", CSS::PROP_OVERFLOW},
    {"z-index", CSS::PROP_Z_INDEX},
    {"font-size", CSS::PROP_FONT_SIZE},
    {"font-family", CSS::PROP_FONT_FAMILY},
    {"font-weight", CSS::PROP_FONT_WEIGHT},
    {"font-style", CSS::PROP_FONT_STYLE},
    {"text-align", CSS::PROP_TEXT_ALIGN},
    {"line-height", CSS::PROP_LINE_HEIGHT},
    {"color", CSS::PROP_COLOR},
    {"text-decoration", CSS::PROP_TEXT_DECORATION},
    {"white-space", CSS::PROP_WHITE_SPACE},
    {"transform", CSS::PROP_TRANSFORM},
    {"transform-origin", CSS::PROP_TRANSFORM_ORIGIN},
    {"transition", CSS::PROP_TRANSITION},
    {"animation", CSS::PROP_ANIMATION},
    {"animation-name", CSS::PROP_ANIMATION_NAME},
    {"animation-duration", CSS::PROP_ANIMATION_DURATION},
    {"animation-timing-function", CSS::PROP_ANIMATION_TIMING_FUNCTION},
    {"animation-delay", CSS::PROP_ANIMATION_DELAY},
    {"animation-iteration-count", CSS::PROP_ANIMATION_ITERATION_COUNT},
    {"animation-direction", CSS::PROP_ANIMATION_DIRECTION},
    {nullptr, CSS::PROP_MAX}
};

CSS::PropertyID propertyNameToID(const SIMDString& name) {
    // Linear search for now - in production use perfect hash
    for (int i = 0; property_map[i].name != nullptr; i++) {
        SIMDString prop_name(property_map[i].name);
        if (prop_name.equals(name)) {
            return property_map[i].id;
        }
    }
    return CSS::PROP_MAX;
}

// Color parsing
CSS::Color CSS::Color::parse(const char* str) {
    // Skip whitespace
    while (*str && isspace(*str)) str++;
    
    if (*str == '#') {
        return parseHex(str);
    }
    
    // Named colors
    if (strncmp(str, "rgb", 3) == 0) {
        // rgb() / rgba()
        int r, g, b, a = 255;
        if (str[3] == 'a') {
            sscanf(str, "rgba(%d,%d,%d,%f)", &r, &g, &b, &a);
            a = (int)(a * 255);
        } else {
            sscanf(str, "rgb(%d,%d,%d)", &r, &g, &b);
        }
        return Color(r / 255.0f, g / 255.0f, b / 255.0f, a / 255.0f);
    }
    
    // Named colors lookup
    static struct ColorName {
        const char* name;
        uint32_t rgba;
    } named_colors[] = {
        {"black", 0xFF000000},
        {"white", 0xFFFFFFFF},
        {"red", 0xFFFF0000},
        {"green", 0xFF00FF00},
        {"blue", 0xFF0000FF},
        {"yellow", 0xFFFFFF00},
        {"cyan", 0xFF00FFFF},
        {"magenta", 0xFFFF00FF},
        {"transparent", 0x00000000},
        {"gray", 0xFF808080},
        {"grey", 0xFF808080},
        {nullptr, 0}
    };
    
    for (int i = 0; named_colors[i].name != nullptr; i++) {
        if (strcasecmp(str, named_colors[i].name) == 0) {
            uint32_t c = named_colors[i].rgba;
            return Color(
                ((c >> 16) & 0xFF) / 255.0f,
                ((c >> 8) & 0xFF) / 255.0f,
                (c & 0xFF) / 255.0f,
                ((c >> 24) & 0xFF) / 255.0f
            );
        }
    }
    
    return Color(0, 0, 0, 1); // Default to black
}

CSS::Color CSS::Color::parseHex(const char* hex) {
    // Skip #
    if (*hex == '#') hex++;
    
    int len = strlen(hex);
    int r, g, b, a = 255;
    
    if (len == 3) {
        // Short form #RGB
        sscanf(hex, "%1x%1x%1x", &r, &g, &b);
        r *= 17; g *= 17; b *= 17;
    } else if (len == 4) {
        // Short form #RGBA
        sscanf(hex, "%1x%1x%1x%1x", &r, &g, &b, &a);
        r *= 17; g *= 17; b *= 17; a *= 17;
    } else if (len == 6) {
        // Long form #RRGGBB
        sscanf(hex, "%2x%2x%2x", &r, &g, &b);
    } else if (len == 8) {
        // Long form #RRGGBBAA
        sscanf(hex, "%2x%2x%2x%2x", &r, &g, &b, &a);
    }
    
    return Color(r / 255.0f, g / 255.0f, b / 255.0f, a / 255.0f);
}

// Length conversion
float CSS::Length::toPixels(float base_size, float viewport_width, float viewport_height) const {
    switch (unit) {
        case PX:
            return value;
        case EM:
        case REM:
            return value * base_size;
        case VW:
            return value * viewport_width / 100.0f;
        case VH:
            return value * viewport_height / 100.0f;
        case PERCENT:
            return value * base_size / 100.0f;
        case PT:
            return value * 1.333f; // 1pt = 1.333px
        default:
            return value;
    }
}

// StyleEngine Implementation
void StyleEngine::addStylesheet(const Stylesheet& sheet) {
    stylesheets_.push_back(sheet);
}

StyleEngine::Stylesheet StyleEngine::parseCSS(const char* css, size_t len) {
    Stylesheet sheet;
    
    const char* p = css;
    const char* end = css + len;
    
    while (p < end) {
        // Skip whitespace and comments
        while (p < end && isspace(*p)) p++;
        if (p >= end) break;
        
        if (*p == '/' && p + 1 < end && *(p + 1) == '*') {
            // Skip comment
            p += 2;
            while (p < end && !(*p == '*' && p + 1 < end && *(p + 1) == '/')) p++;
            if (p < end) p += 2;
            continue;
        }
        
        // Parse selector
        const char* selector_start = p;
        while (p < end && *p != '{') p++;
        const char* selector_end = p;
        
        if (p >= end) break;
        
        // Create rule
        Rule rule;
        std::string selector_str(selector_start, selector_end - selector_start);
        // Trim whitespace
        while (!selector_str.empty() && isspace(selector_str.back())) selector_str.pop_back();
        while (!selector_str.empty() && isspace(selector_str.front())) selector_str.erase(0, 1);
        
        rule.selector_string = SIMDString(selector_str.c_str());
        
        // Parse declarations
        p++; // Skip {
        
        while (p < end && *p != '}') {
            // Skip whitespace
            while (p < end && isspace(*p)) p++;
            if (p >= end || *p == '}') break;
            
            // Parse property name
            const char* prop_start = p;
            while (p < end && *p != ':' && *p != '}') p++;
            const char* prop_end = p;
            
            if (p >= end || *p != ':') break;
            p++; // Skip :
            
            // Parse value
            while (p < end && isspace(*p)) p++;
            const char* value_start = p;
            while (p < end && *p != ';' && *p != '}') p++;
            const char* value_end = p;
            
            // Trim property name
            std::string prop_name(prop_start, prop_end - prop_start);
            while (!prop_name.empty() && isspace(prop_name.back())) prop_name.pop_back();
            
            // Trim value
            std::string prop_value(value_start, value_end - value_start);
            while (!prop_value.empty() && isspace(prop_value.back())) prop_value.pop_back();
            
            // Convert to PropertyID and Value
            SIMDString prop_simd(prop_name.c_str());
            CSS::PropertyID prop_id = propertyNameToID(prop_simd);
            
            if (prop_id != CSS::PROP_MAX) {
                CSS::Value value = parseValue(prop_value.c_str());
                rule.declarations.push_back({prop_id, value});
            }
            
            if (p < end && *p == ';') p++;
        }
        
        if (p < end && *p == '}') p++;
        
        // Compile selector to bytecode
        compileSelector(rule);
        
        sheet.rules.push_back(std::move(rule));
    }
    
    return sheet;
}

CSS::Value StyleEngine::parseValue(const char* str) {
    CSS::Value value;
    
    // Skip whitespace
    while (*str && isspace(*str)) str++;
    
    // Check for special values
    if (strcmp(str, "auto") == 0) {
        value.type = CSS::AUTO;
        return value;
    }
    if (strcmp(str, "none") == 0) {
        value.type = CSS::NONE;
        return value;
    }
    
    // Check for number
    if (isdigit(*str) || *str == '.' || *str == '-') {
        char* end;
        float num = strtof(str, &end);
        
        // Check for unit
        if (end && *end) {
            CSS::LengthUnit unit = CSS::PX;
            if (strcmp(end, "px") == 0) unit = CSS::PX;
            else if (strcmp(end, "em") == 0) unit = CSS::EM;
            else if (strcmp(end, "rem") == 0) unit = CSS::REM;
            else if (strcmp(end, "vw") == 0) unit = CSS::VW;
            else if (strcmp(end, "vh") == 0) unit = CSS::VH;
            else if (strcmp(end, "%") == 0) unit = CSS::PERCENT;
            else if (strcmp(end, "pt") == 0) unit = CSS::PT;
            
            if (unit != CSS::PX || strcmp(end, "px") == 0) {
                value.type = CSS::LENGTH;
                value.length.value = num;
                value.length.unit = unit;
                return value;
            }
        }
        
        value.type = CSS::NUMBER;
        value.number = num;
        return value;
    }
    
    // Check for color
    if (*str == '#' || strncmp(str, "rgb", 3) == 0 || 
        strcasecmp(str, "black") == 0 || strcasecmp(str, "white") == 0 ||
        strcasecmp(str, "red") == 0 || strcasecmp(str, "blue") == 0) {
        value.type = CSS::COLOR;
        value.color = CSS::Color::parse(str);
        return value;
    }
    
    // String/ident value
    value.type = CSS::IDENT;
    value.string_value = SIMDString(str);
    return value;
}

void StyleEngine::compileSelector(Rule& rule) {
    // Compile selector string to bytecode for fast matching
    // Simplified implementation - just store the selector
    (void)rule;
}

void StyleEngine::computeStyles(HTMLParser::DOMBuilder::Node* root) {
    if (!root) return;
    
    // Collect all nodes
    std::vector<HTMLParser::DOMBuilder::Node*> nodes;
    std::function<void(HTMLParser::DOMBuilder::Node*)> collectNodes;
    collectNodes = [&nodes, &collectNodes](HTMLParser::DOMBuilder::Node* node) {
        if (!node) return;
        nodes.push_back(node);
        HTMLParser::DOMBuilder::Node* child = node->first_child.load(std::memory_order_acquire);
        while (child) {
            collectNodes(child);
            child = child->next_sibling.load(std::memory_order_acquire);
        }
    };
    collectNodes(root);
    
    // Apply default styles
    for (auto* node : nodes) {
        // Initialize with default computed style
        CSS::ComputedStyle& style = node->computed_style;
        
        // Default display based on tag name
        const char* tag = node->tag_name.hash() ? "" : "";
        if (node->type == HTMLParser::DOMBuilder::Node::ELEMENT) {
            // Map tag to default display
            if (strcmp(tag, "div") == 0 || strcmp(tag, "p") == 0 || 
                strcmp(tag, "h1") == 0 || strcmp(tag, "h2") == 0 ||
                strcmp(tag, "h3") == 0 || strcmp(tag, "section") == 0) {
                style.display.type = CSS::IDENT;
                style.display.string_value = SIMDString("block");
            } else if (strcmp(tag, "span") == 0 || strcmp(tag, "a") == 0 ||
                       strcmp(tag, "strong") == 0 || strcmp(tag, "em") == 0) {
                style.display.type = CSS::IDENT;
                style.display.string_value = SIMDString("inline");
            }
        } else if (node->type == HTMLParser::DOMBuilder::Node::TEXT) {
            style.display.type = CSS::IDENT;
            style.display.string_value = SIMDString("inline");
        }
    }
    
    // Apply stylesheet rules
    for (const auto& sheet : stylesheets_) {
        for (const auto& rule : sheet.rules) {
            // Match selector against all nodes (SIMD-optimized in production)
            for (auto* node : nodes) {
                if (matchSelectorSIMD(rule.bytecode, node)) {
                    // Apply declarations
                    for (const auto& decl : rule.declarations) {
                        applyDeclaration(node->computed_style, decl.first, decl.second);
                    }
                }
            }
        }
    }
}

bool StyleEngine::matchSelectorSIMD(const Rule::SelectorBytecode& bytecode,
                                   HTMLParser::DOMBuilder::Node* node) {
    // Simplified selector matching
    // In production: use SIMD-accelerated string comparison
    (void)bytecode;
    (void)node;
    return true; // Match all for now
}

void StyleEngine::applyDeclaration(CSS::ComputedStyle& style, CSS::PropertyID prop, const CSS::Value& value) {
    switch (prop) {
        case CSS::PROP_DISPLAY:
            style.display = value;
            break;
        case CSS::PROP_POSITION:
            style.position = value;
            break;
        case CSS::PROP_WIDTH:
            style.width = value;
            break;
        case CSS::PROP_HEIGHT:
            style.height = value;
            break;
        case CSS::PROP_MARGIN_TOP:
            style.margin[0] = value;
            break;
        case CSS::PROP_MARGIN_RIGHT:
            style.margin[1] = value;
            break;
        case CSS::PROP_MARGIN_BOTTOM:
            style.margin[2] = value;
            break;
        case CSS::PROP_MARGIN_LEFT:
            style.margin[3] = value;
            break;
        case CSS::PROP_PADDING_TOP:
            style.padding[0] = value;
            break;
        case CSS::PROP_PADDING_RIGHT:
            style.padding[1] = value;
            break;
        case CSS::PROP_PADDING_BOTTOM:
            style.padding[2] = value;
            break;
        case CSS::PROP_PADDING_LEFT:
            style.padding[3] = value;
            break;
        case CSS::PROP_FLEX_GROW:
            style.flex_grow = value;
            break;
        case CSS::PROP_FLEX_SHRINK:
            style.flex_shrink = value;
            break;
        case CSS::PROP_FLEX_BASIS:
            style.flex_basis = value;
            break;
        case CSS::PROP_BACKGROUND_COLOR:
            style.background_color = value;
            break;
        case CSS::PROP_OPACITY:
            style.opacity = value;
            break;
        case CSS::PROP_FONT_SIZE:
            style.font_size = value;
            break;
        case CSS::PROP_FONT_FAMILY:
            style.font_family = value;
            break;
        case CSS::PROP_COLOR:
            style.color = value;
            break;
        case CSS::PROP_LINE_HEIGHT:
            style.line_height = value;
            break;
        case CSS::PROP_TEXT_ALIGN:
            style.text_align = value;
            break;
        default:
            break;
    }
}

CSS::ComputedStyle StyleEngine::getComputedStyle(HTMLParser::DOMBuilder::Node* node) {
    if (!node) return CSS::ComputedStyle();
    return node->computed_style;
}

bool CSS::ComputedStyle::operator==(const ComputedStyle& other) const {
    // Fast SIMD comparison would go here
    return memcmp(this, &other, sizeof(ComputedStyle)) == 0;
}

bool CSS::Value::operator==(const Value& other) const {
    if (type != other.type) return false;
    
    switch (type) {
        case NUMBER:
            return number == other.number;
        case COLOR:
            return color.r == other.color.r && color.g == other.color.g &&
                   color.b == other.color.b && color.a == other.color.a;
        case LENGTH:
            return length.value == other.length.value && length.unit == other.length.unit;
        case STRING:
        case IDENT:
            return string_value.equals(other.string_value);
        default:
            return true;
    }
}

} // namespace Vortex
