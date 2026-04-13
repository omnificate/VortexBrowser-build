#include "vortex/CSS.h"
#include "vortex/HTMLParser.h"
#include <cctype>
#include <algorithm>

namespace Vortex {

std::vector<CSSRule> CSSParser::parse(const std::string& css) {
    std::vector<CSSRule> rules;
    pos_ = 0;
    
    while (pos_ < css.size()) {
        skipComment(css);
        skipWhitespace(css);
        if (pos_ >= css.size()) break;
        
        auto rule = parseRule(css);
        if (!rule.selector.empty()) {
            rules.push_back(rule);
        }
    }
    
    return rules;
}

void CSSParser::skipWhitespace(const std::string& css) {
    while (pos_ < css.size() && isspace(css[pos_])) {
        ++pos_;
    }
}

void CSSParser::skipComment(const std::string& css) {
    if (pos_ + 1 < css.size() && css[pos_] == '/' && css[pos_+1] == '*') {
        pos_ += 2;
        while (pos_ + 1 < css.size() && !(css[pos_] == '*' && css[pos_+1] == '/')) {
            ++pos_;
        }
        pos_ += 2;
    }
}

CSSRule CSSParser::parseRule(const std::string& css) {
    CSSRule rule;
    rule.specificity = 0;
    
    rule.selector = parseSelector(css);
    rule.specificity = calculateSpecificity(rule.selector);
    
    skipWhitespace(css);
    if (pos_ < css.size() && css[pos_] == '{') {
        ++pos_;
        
        while (pos_ < css.size() && css[pos_] != '}') {
            skipWhitespace(css);
            if (css[pos_] == '}') break;
            
            auto prop = parseProperty(css);
            rule.properties.push_back(prop);
            skipWhitespace(css);
            
            if (pos_ < css.size() && css[pos_] == ';') ++pos_;
        }
        
        if (pos_ < css.size() && css[pos_] == '}') ++pos_;
    }
    
    return rule;
}

std::string CSSParser::parseSelector(const std::string& css) {
    std::string selector;
    skipWhitespace(css);
    
    while (pos_ < css.size() && css[pos_] != '{') {
        selector += css[pos_++];
    }
    
    // Trim whitespace
    size_t start = selector.find_first_not_of(" \t\n\r");
    size_t end = selector.find_last_not_of(" \t\n\r");
    if (start != std::string::npos) {
        selector = selector.substr(start, end - start + 1);
    }
    
    return selector;
}

CSSProperty CSSParser::parseProperty(const std::string& css) {
    CSSProperty prop;
    prop.specificity = 0;
    
    // Parse property name
    std::string name;
    while (pos_ < css.size() && css[pos_] != ':' && css[pos_] != ';' && css[pos_] != '}') {
        name += css[pos_++];
    }
    
    // Trim
    size_t start = name.find_first_not_of(" \t\n\r");
    size_t end = name.find_last_not_of(" \t\n\r");
    if (start != std::string::npos) {
        prop.name = name.substr(start, end - start + 1);
    }
    std::transform(prop.name.begin(), prop.name.end(), prop.name.begin(), ::tolower);
    
    if (pos_ < css.size() && css[pos_] == ':') {
        ++pos_;
        skipWhitespace(css);
        
        // Parse value
        while (pos_ < css.size() && css[pos_] != ';' && css[pos_] != '}') {
            prop.value += css[pos_++];
        }
        
        // Trim value
        size_t vs = prop.value.find_first_not_of(" \t\n\r");
        size_t ve = prop.value.find_last_not_of(" \t\n\r");
        if (vs != std::string::npos) {
            prop.value = prop.value.substr(vs, ve - vs + 1);
        }
    }
    
    return prop;
}

int CSSParser::calculateSpecificity(const std::string& selector) {
    int specificity = 0;
    
    // ID selectors
    size_t pos = 0;
    while ((pos = selector.find('#', pos)) != std::string::npos) {
        specificity += 100;
        ++pos;
    }
    
    // Class selectors, attribute selectors, pseudo-classes
    pos = 0;
    while ((pos = selector.find('.', pos)) != std::string::npos) {
        specificity += 10;
        ++pos;
    }
    
    // Type selectors, pseudo-elements
    // Just add 1 for any non-special character
    if (!selector.empty() && specificity == 0) {
        specificity = 1;
    }
    
    return specificity;
}

// StyleEngine implementation
void StyleEngine::addRules(const std::vector<CSSRule>& rules) {
    rules_.insert(rules_.end(), rules.begin(), rules.end());
}

void StyleEngine::computeStyles(const DOMNodePtr& root) {
    if (!root) return;
    
    // Apply styles to this node
    if (root->type == NodeType::ELEMENT) {
        ComputedStyle style;
        
        // Find matching rules and apply
        for (const auto& rule : rules_) {
            if (matchesSelector(root, rule.selector)) {
                cascadeStyles(style, rule.properties);
            }
        }
        
        // Apply inline styles
        auto inline_style = root->attributes.find("style");
        if (inline_style != root->attributes.end()) {
            // Parse inline styles
            CSSProperty prop;
            size_t pos = 0;
            std::string css = inline_style->second;
            
            while (pos < css.size()) {
                // Simple inline style parsing
                size_t colon = css.find(':', pos);
                if (colon == std::string::npos) break;
                
                std::string name = css.substr(pos, colon - pos);
                // Trim
                size_t ns = name.find_first_not_of(" \t");
                size_t ne = name.find_last_not_of(" \t");
                if (ns != std::string::npos) {
                    name = name.substr(ns, ne - ns + 1);
                }
                std::transform(name.begin(), name.end(), name.begin(), ::tolower);
                
                pos = colon + 1;
                size_t semi = css.find(';', pos);
                std::string value;
                if (semi == std::string::npos) {
                    value = css.substr(pos);
                    pos = css.size();
                } else {
                    value = css.substr(pos, semi - pos);
                    pos = semi + 1;
                }
                
                // Trim value
                size_t vs = value.find_first_not_of(" \t");
                size_t ve = value.find_last_not_of(" \t");
                if (vs != std::string::npos) {
                    value = value.substr(vs, ve - vs + 1);
                }
                
                std::vector<CSSProperty> inline_props;
                CSSProperty p;
                p.name = name;
                p.value = value;
                inline_props.push_back(p);
                cascadeStyles(style, inline_props);
            }
        }
        
        computed_styles_[root] = style;
    }
    
    // Recursively compute for children
    for (auto& child : root->children) {
        computeStyles(child);
    }
}

void StyleEngine::computeStylesParallel(std::vector<DOMNodePtr>& nodes) {
    // Simple sequential version for now
    for (auto& node : nodes) {
        computeStyles(node);
    }
}

ComputedStyle StyleEngine::getComputedStyle(const DOMNodePtr& node) {
    auto it = computed_styles_.find(node);
    if (it != computed_styles_.end()) {
        return it->second;
    }
    return ComputedStyle();
}

void StyleEngine::updateStyles(const DOMNodePtr& changed_node) {
    computeStyles(changed_node);
}

bool StyleEngine::matchesSelector(const DOMNodePtr& node, const std::string& selector) {
    if (node->type != NodeType::ELEMENT) return false;
    
    std::string simple_selector = selector;
    // Remove pseudo-classes for basic matching
    size_t colon = simple_selector.find(':');
    if (colon != std::string::npos) {
        simple_selector = simple_selector.substr(0, colon);
    }
    
    // Tag selector
    if (simple_selector == node->tag) return true;
    
    // Class selector
    if (simple_selector.find('.') != std::string::npos) {
        auto cls_attr = node->attributes.find("class");
        if (cls_attr != node->attributes.end()) {
            std::string class_name = simple_selector.substr(simple_selector.find('.') + 1);
            return cls_attr->second.find(class_name) != std::string::npos;
        }
    }
    
    // ID selector
    if (simple_selector.find('#') != std::string::npos) {
        auto id_attr = node->attributes.find("id");
        if (id_attr != node->attributes.end()) {
            std::string id_name = simple_selector.substr(simple_selector.find('#') + 1);
            return id_attr->second == id_name;
        }
    }
    
    // Universal selector
    if (simple_selector == "*") return true;
    
    return false;
}

void StyleEngine::cascadeStyles(ComputedStyle& style, const std::vector<CSSProperty>& properties) {
    for (const auto& prop : properties) {
        if (prop.name == "display") {
            if (prop.value == "none") style.display = DisplayType::NONE;
            else if (prop.value == "flex") style.display = DisplayType::FLEX;
            else if (prop.value == "grid") style.display = DisplayType::GRID;
            else if (prop.value == "inline") style.display = DisplayType::INLINE;
            else style.display = DisplayType::BLOCK;
        }
        else if (prop.name == "position") {
            if (prop.value == "absolute") style.position = PositionType::ABSOLUTE;
            else if (prop.value == "relative") style.position = PositionType::RELATIVE;
            else if (prop.value == "fixed") style.position = PositionType::FIXED;
            else if (prop.value == "sticky") style.position = PositionType::STICKY;
            else style.position = PositionType::STATIC;
        }
        else if (prop.name == "width") {
            style.width = std::stof(prop.value);
        }
        else if (prop.name == "height") {
            style.height = std::stof(prop.value);
        }
        else if (prop.name == "margin") {
            float val = std::stof(prop.value);
            style.margin_top = style.margin_right = style.margin_bottom = style.margin_left = val;
        }
        else if (prop.name == "padding") {
            float val = std::stof(prop.value);
            style.padding_top = style.padding_right = style.padding_bottom = style.padding_left = val;
        }
        else if (prop.name == "background-color") {
            // Simple color parsing (just basic colors for now)
            if (prop.value == "white" || prop.value == "#ffffff" || prop.value == "#fff") {
                style.background_color = Color(1, 1, 1, 1);
            } else if (prop.value == "black" || prop.value == "#000000" || prop.value == "#000") {
                style.background_color = Color(0, 0, 0, 1);
            } else if (prop.value == "red") {
                style.background_color = Color(1, 0, 0, 1);
            } else if (prop.value == "green") {
                style.background_color = Color(0, 1, 0, 1);
            } else if (prop.value == "blue") {
                style.background_color = Color(0, 0, 1, 1);
            }
        }
        else if (prop.name == "color") {
            if (prop.value == "white" || prop.value == "#ffffff") {
                style.text_color = Color(1, 1, 1, 1);
            } else if (prop.value == "black" || prop.value == "#000000") {
                style.text_color = Color(0, 0, 0, 1);
            } else if (prop.value == "red") {
                style.text_color = Color(1, 0, 0, 1);
            }
        }
        else if (prop.name == "font-size") {
            style.font_size = std::stof(prop.value);
        }
    }
}

void StyleEngine::applyAnimation(const DOMNodePtr& node, const std::string& property,
                                  float start_val, float end_val, float duration) {
    // Stub - would implement actual animation logic
}

void StyleEngine::applyAnimations(const DOMNodePtr& root) {
    // Stub - would apply all active animations
}

} // namespace Vortex
