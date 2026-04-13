#pragma once

#include "Core.h"
#include <vector>
#include <functional>
#include <simd/simd.h>

namespace Vortex {

// SIMD-accelerated HTML tokenizer
// Processes 16 characters at a time using vectorized operations
class HTMLTokenizer {
public:
    enum TokenType {
        DOCTYPE,
        START_TAG,
        END_TAG,
        COMMENT,
        CHARACTER,
        EOF_TOKEN
    };
    
    struct Token {
        TokenType type;
        SIMDString tag_name;
        std::vector<std::pair<SIMDString, SIMDString>> attributes;
        MemoryBuffer data;
        bool self_closing = false;
    };
    
    // Parse state
    enum State {
        DATA_STATE,
        TAG_OPEN_STATE,
        TAG_NAME_STATE,
        BEFORE_ATTRIBUTE_NAME_STATE,
        ATTRIBUTE_NAME_STATE,
        AFTER_ATTRIBUTE_NAME_STATE,
        BEFORE_ATTRIBUTE_VALUE_STATE,
        ATTRIBUTE_VALUE_DOUBLE_QUOTED_STATE,
        ATTRIBUTE_VALUE_SINGLE_QUOTED_STATE,
        ATTRIBUTE_VALUE_UNQUOTED_STATE,
        MARKUP_DECLARATION_OPEN_STATE,
        COMMENT_START_STATE,
        COMMENT_STATE,
        COMMENT_END_STATE
    };
    
private:
    const char* input_;
    size_t input_size_;
    size_t position_ = 0;
    State state_ = DATA_STATE;
    
    // SIMD vector for character classification
    alignas(64) uint8_t char_class_[256];
    
    // Current token being built
    Token current_token_;
    SIMDString current_attribute_name_;
    SIMDString current_attribute_value_;
    
    // Fast character class lookup using SIMD
    static constexpr uint8_t CHAR_WHITESPACE = 1;
    static constexpr uint8_t CHAR_TAG_OPEN = 2;     // <
    static constexpr uint8_t CHAR_TAG_CLOSE = 4;      // >
    static constexpr uint8_t CHAR_SLASH = 8;        // /
    static constexpr uint8_t CHAR_EQUALS = 16;      // =
    static constexpr uint8_t CHAR_QUOTE = 32;        // "
    static constexpr uint8_t CHAR_APOS = 64;        // '
    static constexpr uint8_t CHAR_EXCLAMATION = 128; // !
    
    void initCharClasses() {
        memset(char_class_, 0, 256);
        char_class_['\t'] = char_class_['\n'] = char_class_['\r'] = char_class_[' '] = CHAR_WHITESPACE;
        char_class_['<'] = CHAR_TAG_OPEN;
        char_class_['>'] = CHAR_TAG_CLOSE;
        char_class_['/'] = CHAR_SLASH;
        char_class_['='] = CHAR_EQUALS;
        char_class_['"'] = CHAR_QUOTE;
        char_class_["'"] = CHAR_APOS;
        char_class_['!'] = CHAR_EXCLAMATION;
    }
    
    // SIMD scan for tag characters
    size_t scanTagCharactersSIMD() {
        size_t start = position_;
        
        while (position_ + 16 <= input_size_) {
            // Load 16 bytes
            uint8_t chars[16];
            memcpy(chars, input_ + position_, 16);
            
            // Check for any special character in the block
            bool found_special = false;
            for (int i = 0; i < 16; i++) {
                uint8_t cls = char_class_[chars[i]];
                if (cls & (CHAR_WHITESPACE | CHAR_TAG_CLOSE | CHAR_SLASH)) {
                    found_special = true;
                    break;
                }
            }
            
            if (found_special) {
                // Scan byte by byte in this block
                while (position_ < start + 16 && position_ < input_size_) {
                    uint8_t c = input_[position_];
                    uint8_t cls = char_class_[c];
                    if (cls & (CHAR_WHITESPACE | CHAR_TAG_CLOSE | CHAR_SLASH)) {
                        return position_ - start;
                    }
                    position_++;
                }
            } else {
                position_ += 16;
            }
        }
        
        // Handle remaining bytes
        while (position_ < input_size_) {
            uint8_t c = input_[position_];
            uint8_t cls = char_class_[c];
            if (cls & (CHAR_WHITESPACE | CHAR_TAG_CLOSE | CHAR_SLASH)) {
                break;
            }
            position_++;
        }
        
        return position_ - start;
    }
    
    char nextChar() {
        if (position_ >= input_size_) return '\0';
        return input_[position_++];
    }
    
    char peekChar() {
        if (position_ >= input_size_) return '\0';
        return input_[position_];
    }
    
    void emitToken(Token& token);
    
public:
    explicit HTMLTokenizer(const char* input, size_t size) 
        : input_(input), input_size_(size) {
        initCharClasses();
    }
    
    // Streaming parse - emits tokens via callback
    void parseStreaming(std::function<void(Token&&)> token_handler);
    
    // Batch parse - returns all tokens
    std::vector<Token> parse();
    
    // State machine step
    bool step();
};

// Concurrent DOM construction
class DOMBuilder {
public:
    struct Node {
        enum Type {
            ELEMENT,
            TEXT,
            COMMENT,
            DOCUMENT,
            DOCUMENT_TYPE
        };
        
        Type type;
        SIMDString tag_name;
        SIMDString text_content;
        std::vector<std::pair<SIMDString, SIMDString>> attributes;
        
        // Tree structure using lock-free pointers
        std::atomic<Node*> parent{nullptr};
        std::atomic<Node*> first_child{nullptr};
        std::atomic<Node*> next_sibling{nullptr};
        std::atomic<Node*> prev_sibling{nullptr};
        std::atomic<Node*> last_child{nullptr};
        
        // For fast lookup
        uint32_t node_id;
        uint32_t depth;
        
        // Layout cache
        std::atomic<bool> needs_layout{true};
        std::atomic<bool> needs_paint{true};
        
        // Memory pool allocation
        static LockFreePool<Node, 1024> pool;
        
        void* operator new(size_t) { return pool.allocate(); }
        void operator delete(void*) { /* pool-managed */ }
    };
    
private:
    Node* document_;
    Node* current_parent_;
    std::vector<Node*> stack_;
    
    // Lock-free insertion
    void appendChild(Node* parent, Node* child);
    void insertBefore(Node* parent, Node* child, Node* reference);
    void removeChild(Node* child);
    
public:
    DOMBuilder();
    
    Node* document() const { return document_; }
    
    // Process token into DOM
    void processToken(HTMLTokenizer::Token&& token);
    
    // Get element by ID using lock-free hash
    Node* getElementById(const SIMDString& id);
    
    // Query selector using SIMD-accelerated matching
    std::vector<Node*> querySelectorAll(const char* selector);
    
    // Incremental update - only marks changed subtrees
    void markDirty(Node* node);
    void markSubtreeDirty(Node* node);
};

// Streaming parser that combines tokenization and DOM construction
class StreamingHTMLParser {
    HTMLTokenizer tokenizer_;
    DOMBuilder builder_;
    
public:
    StreamingHTMLParser(const char* input, size_t size)
        : tokenizer_(input, size) {}
    
    // Parse incrementally - yields control periodically
    void parseIncremental(size_t chunk_size = 1024);
    
    // Full parse
    DOMBuilder::Node* parse() {
        tokenizer_.parseStreaming([this](HTMLTokenizer::Token&& token) {
            builder_.processToken(std::move(token));
        });
        return builder_.document();
    }
    
    DOMBuilder& builder() { return builder_; }
};

// HTML5-compliant entity decoder with SIMD lookup
class EntityDecoder {
    static ConcurrentHashMap<SIMDString, uint32_t, 256> entity_map_;
    
public:
    static void initialize();
    static uint32_t decode(const char* entity, size_t len);
    static size_t decodeString(const char* input, size_t len, char* output);
};

} // namespace Vortex
