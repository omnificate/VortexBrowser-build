//
// Vortex Engine Unit Tests
// Tests for core engine components
//

#include "vortex/Core.h"
#include "vortex/HTMLParser.h"
#include "vortex/CSS.h"
#include <iostream>
#include <cassert>
#include <chrono>

using namespace Vortex;

// Test helper
#define TEST(name) void test_##name()
#define RUN_TEST(name) do { \
    std::cout << "Running " #name "... "; \
    test_##name(); \
    std::cout << "✓ PASSED" << std::endl; \
} while(0)

// SIMD String tests
TEST(simd_string) {
    SIMDString str1("Hello World");
    SIMDString str2("Hello World");
    SIMDString str3("Different");
    
    assert(str1.equals(str2));
    assert(!str1.equals(str3));
    assert(str1.hash() == str2.hash());
    
    // Test longer strings
    SIMDString long1("This is a longer string for testing SIMD comparison");
    SIMDString long2("This is a longer string for testing SIMD comparison");
    assert(long1.equals(long2));
}

// Memory buffer tests
TEST(memory_buffer) {
    MemoryBuffer owned(1024);
    assert(owned.data() != nullptr);
    assert(owned.size() == 1024);
    
    char test_data[] = "Test data for buffer view";
    MemoryBuffer view = MemoryBuffer::view(test_data, sizeof(test_data));
    assert(view.data() == test_data);
    assert(view.size() == sizeof(test_data));
    
    // Test slicing
    MemoryBuffer slice = view.slice(5, 10);
    assert(slice.size() == 10);
}

// Concurrent hash map tests
TEST(concurrent_hash_map) {
    ConcurrentHashMap<SIMDString, int, 256> map;
    
    SIMDString key1("test_key_1");
    int value1 = 42;
    map.insert(key1, &value1);
    
    int* found = map.find(key1);
    assert(found != nullptr);
    assert(*found == 42);
    
    SIMDString key2("nonexistent");
    int* notfound = map.find(key2);
    assert(notfound == nullptr);
}

// HTML Tokenizer tests
TEST(html_tokenizer) {
    const char* html = "<html><body><h1>Title</h1><p>Paragraph</p></body></html>";
    HTMLTokenizer tokenizer(html, strlen(html));
    
    std::vector<HTMLTokenizer::Token> tokens;
    tokenizer.parseStreaming([&tokens](HTMLTokenizer::Token&& token) {
        tokens.push_back(std::move(token));
    });
    
    // Verify we got tokens
    assert(!tokens.empty());
    
    // Check first token is start tag
    bool found_html = false;
    for (const auto& token : tokens) {
        if (token.type == HTMLTokenizer::START_TAG) {
            SIMDString html_tag("html");
            if (token.tag_name.equals(html_tag)) {
                found_html = true;
                break;
            }
        }
    }
    assert(found_html);
}

// DOM Builder tests
TEST(dom_builder) {
    const char* html = "<div><p>Test</p></div>";
    StreamingHTMLParser parser(html, strlen(html));
    
    HTMLParser::DOMBuilder::Node* root = parser.parse();
    assert(root != nullptr);
    assert(root->type == HTMLParser::DOMBuilder::Node::DOCUMENT);
    
    // Check first child is div
    HTMLParser::DOMBuilder::Node* child = root->first_child.load(std::memory_order_acquire);
    assert(child != nullptr);
    assert(child->type == HTMLParser::DOMBuilder::Node::ELEMENT);
    
    SIMDString div_tag("div");
    assert(child->tag_name.equals(div_tag));
}

// CSS Parser tests
TEST(css_parser) {
    StyleEngine engine;
    
    const char* css = R"(
        body {
            background-color: #ffffff;
            font-size: 16px;
        }
        h1 {
            color: #333333;
            font-weight: bold;
        }
    )";
    
    StyleEngine::Stylesheet sheet = engine.parseCSS(css, strlen(css));
    assert(!sheet.rules.empty());
    
    // Check first rule is for body
    assert(sheet.rules[0].declarations.size() > 0);
}

// CSS Color tests
TEST(css_color) {
    CSS::Color c1 = CSS::Color::parse("#FF5733");
    assert(c1.r > 0.9f && c1.r <= 1.0f);
    assert(c1.g > 0.3f && c1.g < 0.4f);
    assert(c1.b > 0.1f && c1.b < 0.25f);
    
    CSS::Color c2 = CSS::Color::parse("rgb(255, 128, 64)");
    assert(c2.r > 0.9f);
    assert(c2.g > 0.45f && c2.g < 0.55f);
    assert(c2.b > 0.2f && c2.b < 0.3f);
    
    CSS::Color c3 = CSS::Color::parse("blue");
    assert(c3.b > 0.9f);
    assert(c3.r < 0.1f);
    assert(c3.g < 0.1f);
}

// Performance benchmark
TEST(performance_benchmark) {
    // HTML parsing benchmark
    const char* large_html = R"(
        <html>
        <head><title>Test</title></head>
        <body>
    )";
    
    // Create larger HTML
    std::string html = large_html;
    for (int i = 0; i < 1000; i++) {
        html += "<div class='item' style='padding: 10px; margin: 5px;'><p>Content " + std::to_string(i) + "</p></div>\n";
    }
    html += "</body></html>";
    
    // Parse
    auto start = std::chrono::high_resolution_clock::now();
    StreamingHTMLParser parser(html.c_str(), html.length());
    HTMLParser::DOMBuilder::Node* root = parser.parse();
    auto end = std::chrono::high_resolution_clock::now();
    
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(end - start);
    std::cout << " (" << duration.count() << "μs)";
    
    assert(root != nullptr);
    
    // Should be fast - less than 100ms for 1000 elements
    assert(duration.count() < 100000);
}

// Layout engine tests
TEST(layout_engine) {
    Layout::LayoutEngine engine;
    
    const char* html = R"(
        <div style='display: block; width: 100px; height: 100px;'>
            <p style='font-size: 16px;'>Text</p>
        </div>
    )";
    
    StreamingHTMLParser parser(html, strlen(html));
    HTMLParser::DOMBuilder::Node* root = parser.parse();
    
    engine.layoutDocument(root, 1024, 768);
    
    Layout::LayoutNode* layout_root = engine.getLayoutTree();
    assert(layout_root != nullptr);
}

// Main test runner
int main(int argc, char** argv) {
    (void)argc;
    (void)argv;
    
    std::cout << "========================================" << std::endl;
    std::cout << "Vortex Engine Test Suite" << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << std::endl;
    
    std::cout << "Core Tests:" << std::endl;
    RUN_TEST(simd_string);
    RUN_TEST(memory_buffer);
    RUN_TEST(concurrent_hash_map);
    std::cout << std::endl;
    
    std::cout << "HTML Parser Tests:" << std::endl;
    RUN_TEST(html_tokenizer);
    RUN_TEST(dom_builder);
    std::cout << std::endl;
    
    std::cout << "CSS Tests:" << std::endl;
    RUN_TEST(css_parser);
    RUN_TEST(css_color);
    std::cout << std::endl;
    
    std::cout << "Layout Tests:" << std::endl;
    RUN_TEST(layout_engine);
    std::cout << std::endl;
    
    std::cout << "Performance Tests:" << std::endl;
    RUN_TEST(performance_benchmark);
    std::cout << std::endl;
    
    std::cout << "========================================" << std::endl;
    std::cout << "All tests passed! ✓" << std::endl;
    std::cout << "========================================" << std::endl;
    
    return 0;
}
