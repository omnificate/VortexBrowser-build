#pragma once
#include <string>
#include <vector>
#include <memory>
#include <unordered_map>
#include <cstring>

namespace Vortex {

struct DOMNode;
using DOMNodePtr = std::shared_ptr<DOMNode>;

enum NodeType { ELEMENT, TEXT, COMMENT, DOCUMENT };

struct DOMNode {
    NodeType type;
    std::string tag;
    std::string text;
    std::unordered_map<std::string, std::string> attributes;
    std::vector<DOMNodePtr> children;
    DOMNodePtr parent;
    
    DOMNode(NodeType t) : type(t), parent(nullptr) {}
};

class HTMLParser {
public:
    DOMNodePtr parse(const std::string& html);
    
private:
    enum CharClass {
        CHAR_NORMAL = 0,
        CHAR_LT = 1,
        CHAR_GT = 2,
        CHAR_SLASH = 3,
        CHAR_SPACE = 4,
        CHAR_QUOTE = 5,
        CHAR_APOS = 6,
        CHAR_EQ = 7
    };
    
    static const int CHAR_TABLE_SIZE = 256;
    unsigned char char_class_[CHAR_TABLE_SIZE];
    
    void initCharClass() {
        memset(char_class_, CHAR_NORMAL, CHAR_TABLE_SIZE);
        char_class_[static_cast<unsigned char>('<')] = CHAR_LT;
        char_class_[static_cast<unsigned char>('>')] = CHAR_GT;
        char_class_[static_cast<unsigned char>('/')] = CHAR_SLASH;
        char_class_[static_cast<unsigned char>(' ')] = CHAR_SPACE;
        char_class_[static_cast<unsigned char>('\t')] = CHAR_SPACE;
        char_class_[static_cast<unsigned char>('\n')] = CHAR_SPACE;
        char_class_[static_cast<unsigned char>('\r')] = CHAR_SPACE;
        char_class_[static_cast<unsigned char>('"')] = CHAR_QUOTE;
        char_class_[static_cast<unsigned char>(''')] = CHAR_APOS;
        char_class_[static_cast<unsigned char>('=')] = CHAR_EQ;
    }
    
    size_t pos_;
    
    DOMNodePtr parseNode(const std::string& html);
    DOMNodePtr parseElement(const std::string& html);
    std::string parseText(const std::string& html);
    std::string parseTagName(const std::string& html);
    std::unordered_map<std::string, std::string> parseAttributes(const std::string& html);
};

} // namespace Vortex
