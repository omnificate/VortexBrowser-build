#pragma once
#include <string>
#include <vector>
#include <unordered_map>
#include <memory>
#include <variant>
#include <functional>

namespace Vortex {

// Forward declarations
struct DOMNode;
using DOMNodePtr = std::shared_ptr<DOMNode>;

enum class JSValueType { NUMBER, STRING, BOOL, OBJECT, ARRAY, NULL_VAL, UNDEFINED };

struct JSValue {
    JSValueType type;
    std::variant<double, std::string, bool, std::monostate> data;
    std::unordered_map<std::string, std::shared_ptr<JSValue>> properties;
    std::vector<std::shared_ptr<JSValue>> array_elements;
    
    JSValue() : type(JSValueType::UNDEFINED), data(std::monostate()) {}
    explicit JSValue(double num) : type(JSValueType::NUMBER), data(num) {}
    explicit JSValue(const std::string& str) : type(JSValueType::STRING), data(str) {}
    explicit JSValue(bool b) : type(JSValueType::BOOL), data(b) {}
    static JSValue null() { JSValue v; v.type = JSValueType::NULL_VAL; return v; }
    
    bool isNumber() const { return type == JSValueType::NUMBER; }
    bool isString() const { return type == JSValueType::STRING; }
    bool isBool() const { return type == JSValueType::BOOL; }
    bool isNull() const { return type == JSValueType::NULL_VAL; }
    bool isUndefined() const { return type == JSValueType::UNDEFINED; }
    
    double asNumber() const { return std::get<double>(data); }
    std::string asString() const { return std::get<std::string>(data); }
    bool asBool() const { return std::get<bool>(data); }
};

enum class OpCode {
    LOAD_CONST, LOAD_VAR, STORE_VAR,
    ADD, SUB, MUL, DIV, MOD,
    EQ, NEQ, LT, GT, LE, GE,
    JMP, JMP_IF_FALSE,
    CALL, RET,
    GET_PROP, SET_PROP,
    GET_ELEM, SET_ELEM,
    NEW_OBJ, NEW_ARRAY,
    PUSH, POP
};

struct Instruction {
    OpCode opcode;
    int operand;
};

class TurboScript {
public:
    class VM {
    public:
        std::vector<JSValue> stack;
        std::unordered_map<std::string, JSValue> variables;
        std::vector<Instruction> bytecode;
        size_t pc;
        
        VM() : pc(0) {}
        
        void execute(const std::vector<Instruction>& code);
        JSValue callFunction(const std::string& name, const std::vector<JSValue>& args);
    };
    
    // AST Node types
    enum class ASTNodeType {
        PROGRAM, FUNCTION, VAR_DECL, BLOCK,
        BINARY_OP, UNARY_OP, LITERAL, IDENTIFIER,
        CALL, MEMBER, ASSIGN, ARRAY, OBJECT
    };
    
    struct ASTNode {
        ASTNodeType type;
        std::vector<std::shared_ptr<ASTNode>> children;
        std::string value;
        double number_val;
        int line, column;
    };
    
    std::shared_ptr<ASTNode> parse(const std::string& source);
    std::vector<Instruction> compile(const std::shared_ptr<ASTNode>& ast);
    
    void compileNode(const std::shared_ptr<ASTNode>& node);
    void compileStatement(const std::shared_ptr<ASTNode>& node);
    void compileExpression(const std::shared_ptr<ASTNode>& node);
    
    // Inline cache for property access
    struct alignas(64) InlineCache {
        uint64_t shape_id;
        int property_offset;
        int total_hits;
        int miss_count;
    };
    
    static const int IC_CACHE_SIZE = 4096;
    InlineCache ic_cache[IC_CACHE_SIZE];
    
    int getInlineCacheIndex(uint64_t shape_id, const std::string& property);
    void updateInlineCache(int index, int offset);
    
    struct JITRegion {
        void* executable_memory;
        size_t size;
        size_t used;
    };
    
    JITRegion jit_region_;
    void initializeJIT();
    void* compileToNative(const std::vector<Instruction>& bytecode);
    
    class DOMBindings {
    public:
        void bindDOM(VM* vm, const DOMNodePtr& root);
        JSValue createDOMWrapper(const DOMNodePtr& node);
        DOMNodePtr unwrapDOM(const JSValue& value);
        
        using EventCallback = std::function<void(const std::string& type, const DOMNodePtr& target)>;
        void registerEventListener(const DOMNodePtr& node, const std::string& event, EventCallback callback);
        
        void dispatchEvent(const std::string& type, const DOMNodePtr& target);
        
    private:
        DOMNode* document_;
        std::unordered_map<DOMNodePtr, std::unordered_map<std::string, std::vector<EventCallback>>> listeners_;
    };
};

} // namespace Vortex
