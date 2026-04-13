#include "vortex/HTMLParser.h"
#include <cctype>
#include <algorithm>

namespace Vortex {

DOMNodePtr HTMLParser::parse(const std::string& html) {
    initCharClass();
    pos_ = 0;
    
    auto document = std::make_shared<DOMNode>(NodeType::DOCUMENT);
    
    while (pos_ < html.size()) {
        skipWhitespace(html);
        if (pos_ >= html.size()) break;
        
        auto node = parseNode(html);
        if (node) {
            document->children.push_back(node);
            node->parent = document;
        }
    }
    
    return document;
}

void HTMLParser::skipWhitespace(const std::string& html) {
    while (pos_ < html.size() && isspace(html[pos_])) {
        ++pos_;
    }
}

DOMNodePtr HTMLParser::parseNode(const std::string& html) {
    if (pos_ >= html.size()) return nullptr;
    
    if (html[pos_] == '<') {
        return parseElement(html);
    } else {
        auto text_node = std::make_shared<DOMNode>(NodeType::TEXT);
        text_node->text = parseText(html);
        return text_node;
    }
}

std::string HTMLParser::parseText(const std::string& html) {
    std::string text;
    while (pos_ < html.size() && html[pos_] != '<') {
        text += html[pos_++];
    }
    return text;
}

DOMNodePtr HTMLParser::parseElement(const std::string& html) {
    if (pos_ >= html.size() || html[pos_] != '<') return nullptr;
    ++pos_; // Skip '<'
    
    // Check for comment
    if (pos_ + 2 < html.size() && html[pos_] == '!' && html[pos_+1] == '-' && html[pos_+2] == '-') {
        pos_ += 3;
        auto comment = std::make_shared<DOMNode>(NodeType::COMMENT);
        while (pos_ + 2 < html.size() && !(html[pos_] == '-' && html[pos_+1] == '-' && html[pos_+2] == '>')) {
            comment->text += html[pos_++];
        }
        pos_ += 3; // Skip '-->'
        return comment;
    }
    
    std::string tag_name = parseTagName(html);
    if (tag_name.empty()) return nullptr;
    
    auto element = std::make_shared<DOMNode>(NodeType::ELEMENT);
    element->tag = tag_name;
    
    // Parse attributes
    element->attributes = parseAttributes(html);
    
    // Self-closing or closing tag
    if (pos_ < html.size() && html[pos_] == '/') {
        ++pos_;
        if (pos_ < html.size() && html[pos_] == '>') {
            ++pos_;
        }
        return element;
    }
    
    if (pos_ < html.size() && html[pos_] == '>') {
        ++pos_;
    }
    
    // Parse children
    while (pos_ < html.size()) {
        if (html[pos_] == '<' && pos_ + 1 < html.size() && html[pos_+1] == '/') {
            // Closing tag
            pos_ += 2;
            std::string closing_tag = parseTagName(html);
            if (pos_ < html.size() && html[pos_] == '>') ++pos_;
            break;
        }
        
        auto child = parseNode(html);
        if (child) {
            element->children.push_back(child);
            child->parent = element;
        }
    }
    
    return element;
}

std::string HTMLParser::parseTagName(const std::string& html) {
    std::string name;
    while (pos_ < html.size() && !isspace(html[pos_]) && html[pos_] != '>' && html[pos_] != '/') {
        name += html[pos_++];
    }
    std::transform(name.begin(), name.end(), name.begin(), ::tolower);
    return name;
}

std::unordered_map<std::string, std::string> HTMLParser::parseAttributes(const std::string& html) {
    std::unordered_map<std::string, std::string> attrs;
    
    while (pos_ < html.size() && html[pos_] != '>' && html[pos_] != '/') {
        skipWhitespace(html);
        if (pos_ >= html.size() || html[pos_] == '>' || html[pos_] == '/') break;
        
        // Parse attribute name
        std::string attr_name;
        while (pos_ < html.size() && !isspace(html[pos_]) && html[pos_] != '=' && html[pos_] != '>' && html[pos_] != '/') {
            attr_name += html[pos_++];
        }
        
        if (attr_name.empty()) {
            ++pos_;
            continue;
        }
        
        std::transform(attr_name.begin(), attr_name.end(), attr_name.begin(), ::tolower);
        
        std::string attr_value;
        if (pos_ < html.size() && html[pos_] == '=') {
            ++pos_;
            skipWhitespace(html);
            
            if (pos_ < html.size() && (html[pos_] == '"' || html[pos_] == '\'')) {
                char quote = html[pos_++];
                while (pos_ < html.size() && html[pos_] != quote) {
                    attr_value += html[pos_++];
                }
                if (pos_ < html.size()) ++pos_;
            } else {
                while (pos_ < html.size() && !isspace(html[pos_]) && html[pos_] != '>' && html[pos_] != '/') {
                    attr_value += html[pos_++];
                }
            }
        }
        
        attrs[attr_name] = attr_value;
    }
    
    return attrs;
}

} // namespace Vortex
