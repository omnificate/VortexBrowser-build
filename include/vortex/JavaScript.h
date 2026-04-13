#pragma once

#include "Core.h"
#include <vector>
#include <functional>
#include <unordered_map>

namespace Vortex {

// TurboScript JavaScript Engine
// High-performance JIT compiler with zero-allocation execution

namespace TurboScript {

// Value representation using NaN boxing
// 64-bit double with special NaN payload for tagged pointers
class Value {
    union {
        double as_double;
        uint64_t as_bits;
        struct {
            uint32_t payload;
            uint32_t tag;
        };
    };
    
    static constexpr uint64_t TAG_MASK = 0xFFFF000000000000ULL;
    static constexpr uint64_t TAG_NUMBER = 0x7FF8000000000000ULL;
    static constexpr uint64_t TAG_SPECIAL = 0x7FF9000000000000ULL;
    
public:
    enum Special : uint32_t {
        UNDEFINED,
        NULL_VALUE,
        TRUE,
        FALSE
    };
    
    Value() : as_bits(TAG_SPECIAL | UNDEFINED) {}
    explicit Value(double num) : as_double(num) {}
    explicit Value(Special s) : as_bits(TAG_SPECIAL | s) {}
    explicit Value(void* ptr, uint16_t type_tag);
    
    bool isNumber() const { return (as_bits & TAG_MASK) != TAG_MASK; }
    bool isObject() const { return (as_bits & 0xFFFF000000000001ULL) == 0xFFFF000000000001ULL; }
    bool isString() const { return (as_bits & 0xFFFF000000000002ULL) == 0xFFFF000000000002ULL; }
    bool isSpecial() const { return (as_bits & TAG_MASK) == TAG_SPECIAL; }
    
    double asNumber() const { return as_double; }
    void* asPointer() const;
    Special asSpecial() const { return static_cast<Special>(payload & 0xFFFF); }
};

// Object representation - flat object model for cache efficiency
struct Object {
    // Shape (hidden class) for fast property access
    struct Shape {
        std::vector<SIMDString> properties;
        std::unordered_map<uint32_t, uint32_t> property_map; // hash -> index
        Shape* parent_shape;
        uint32_t transition_id;
        
        // SIMD-accelerated property lookup
        int findProperty(const SIMDString& name) const;
    };
    
    Shape* shape;
    std::vector<Value> properties;  // Inline storage
    std::unordered_map<uint32_t, Value>* sparse_storage;  // For sparse arrays/objects
    
    // Fast property access
    Value get(const SIMDString& name) const;
    void set(const SIMDString& name, const Value& value);
    
    // Method cache for monomorphic inline caching
    static constexpr size_t IC_CACHE_SIZE = 1024;
    struct InlineCache {
        uint32_t property_hash;
        Shape* shape;
        uint32_t property_index;
        std::atomic<uint64_t> hit_count;
    };
    static alignas(64) InlineCache ic_cache[IC_CACHE_SIZE];
};

// Bytecode instruction format
enum Opcode {
    // Stack operations
    OP_LOAD_CONST,      // Load constant from pool
    OP_LOAD_VAR,        // Load local variable
    OP_STORE_VAR,       // Store to local variable
    OP_LOAD_GLOBAL,     // Load global
    OP_STORE_GLOBAL,    // Store global
    OP_LOAD_PROP,       // Load property (with IC)
    OP_STORE_PROP,      // Store property (with IC)
    OP_LOAD_ELEM,       // Load array element
    OP_STORE_ELEM,      // Store array element
    
    // Arithmetic
    OP_ADD,
    OP_SUB,
    OP_MUL,
    OP_DIV,
    OP_MOD,
    OP_NEG,
    OP_INC,
    OP_DEC,
    
    // Bitwise
    OP_BIT_AND,
    OP_BIT_OR,
    OP_BIT_XOR,
    OP_BIT_NOT,
    OP_SHL,
    OP_SHR,
    OP_USHR,
    
    // Comparison
    OP_EQ,
    OP_NEQ,
    OP_STRICT_EQ,
    OP_STRICT_NEQ,
    OP_LT,
    OP_LTE,
    OP_GT,
    OP_GTE,
    
    // Control flow
    OP_JUMP,
    OP_JUMP_IF_TRUE,
    OP_JUMP_IF_FALSE,
    OP_CALL,
    OP_RETURN,
    OP_THROW,
    OP_TRY,
    OP_CATCH,
    
    // Object operations
    OP_NEW_OBJECT,
    OP_NEW_ARRAY,
    OP_NEW_FUNCTION,
    OP_NEW_REGEXP,
    OP_TYPEOF,
    OP_INSTANCEOF,
    OP_IN,
    
    // Optimized operations
    OP_ADD_INT,         // Integer addition (fast path)
    OP_ADD_DOUBLE,      // Double addition (fast path)
    OP_CALL_FAST,       // Monomorphic call
    OP_PROP_FAST,       // Inline cached property access
    
    // Async/await
    OP_AWAIT,
    OP_RESUME,
    
    OP_HALT
};

struct Instruction {
    uint8_t opcode;
    union {
        uint8_t u8;
        uint16_t u16;
        uint32_t u32;
        int32_t i32;
        float f32;
    } operand;
};

// JIT Compilation tiers
class JITCompiler {
public:
    // Baseline JIT - simple template-based compilation
    void* compileBaseline(const std::vector<Instruction>& bytecode);
    
    // Optimizing JIT - with inlining and register allocation
    void* compileOptimized(const std::vector<Instruction>& bytecode,
                          const std::vector<Instruction*>& hot_paths);
    
    // FTL (Faster Than Light) JIT - full optimization
    void* compileFTL(const std::vector<Instruction>& bytecode,
                    const std::vector<Value*>& type_profile);
    
private:
    // Machine code generation
    void emitPrologue();
    void emitEpilogue();
    void emitLoadConst(uint32_t index);
    void emitLoadVar(uint8_t slot);
    void emitAdd();
    void emitCall(uint8_t argc);
    
    // Platform-specific code generation
    void* getMachineCode() const;
};

// Virtual machine execution engine
class VM {
public:
    struct Frame {
        Instruction* ip;           // Instruction pointer
        Value* sp;                // Stack pointer
        Value* bp;                // Base pointer (frame base)
        Frame* caller;
        Value* local_vars;
        uint32_t local_count;
    };
    
    // Execution modes
    enum ExecutionMode {
        INTERPRET,      // Bytecode interpretation
        BASELINE_JIT,   // Baseline JIT
        OPTIMIZED_JIT,  // Optimizing JIT
        FTL_JIT         // Maximum optimization
    };
    
private:
    // Stack
    static constexpr size_t STACK_SIZE = 1024 * 1024; // 1MB stack
    Value* stack_;
    Value* stack_top_;
    
    // Global object
    Object* global_;
    
    // JIT compiler
    JITCompiler jit_compiler_;
    
    // Execution mode
    ExecutionMode mode_;
    
    // Hot spot detection
    std::unordered_map<Instruction*, uint64_t> execution_count_;
    
    // Interpret single instruction
    bool interpretStep(Frame& frame);
    
    // Garbage collector (generational, incremental)
    class GarbageCollector;
    std::unique_ptr<GarbageCollector> gc_;
    
public:
    VM();
    ~VM();
    
    void initialize();
    
    // Execute function
    Value execute(const std::vector<Instruction>& bytecode,
                 const std::vector<Value>& args);
    
    // Call JS function from native
    Value callFunction(Object* func, const std::vector<Value>& args);
    
    // Set execution mode
    void setExecutionMode(ExecutionMode mode) { mode_ = mode; }
    
    // Native function registration
    using NativeFunction = std::function<Value(VM*, const std::vector<Value>&)>;
    void registerNative(const SIMDString& name, NativeFunction fn);
    
    // Memory management
    void gc_collect(bool full = false);
    size_t heapSize() const;
};

// Parser - converts source to AST
class Parser {
public:
    struct Node {
        enum Type {
            PROGRAM,
            FUNCTION,
            BLOCK,
            VAR_DECL,
            LET_DECL,
            CONST_DECL,
            EXPRESSION_STMT,
            IF_STMT,
            WHILE_STMT,
            FOR_STMT,
            RETURN_STMT,
            TRY_STMT,
            THROW_STMT,
            
            // Expressions
            IDENTIFIER,
            LITERAL,
            BINARY_EXPR,
            UNARY_EXPR,
            ASSIGN_EXPR,
            CALL_EXPR,
            MEMBER_EXPR,
            ARRAY_EXPR,
            OBJECT_EXPR,
            FUNCTION_EXPR,
            ARROW_EXPR,
            NEW_EXPR,
            CONDITIONAL_EXPR
        };
        
        Type type;
        std::vector<Node*> children;
        SIMDString string_value;
        double number_value;
        bool bool_value;
    };
    
    Node* parse(const char* source, size_t len);
    
private:
    const char* input_;
    size_t pos_;
    size_t len_;
    
    Node* parseProgram();
    Node* parseStatement();
    Node* parseExpression();
    Node* parsePrimary();
    Node* parseBinary(Node* left, int precedence);
};

// Compiler - converts AST to bytecode
class Compiler {
public:
    std::vector<Instruction> compile(Node* ast);
    
private:
    std::vector<Instruction> bytecode_;
    
    void emit(Opcode op);
    void emitU8(Opcode op, uint8_t val);
    void emitU16(Opcode op, uint16_t val);
    void emitU32(Opcode op, uint32_t val);
    void emitI32(Opcode op, int32_t val);
    
    void compileNode(Node* node);
    void compileStatement(Node* node);
    void compileExpression(Node* node);
};

} // namespace TurboScript

// JavaScript bridge to DOM
class JavaScriptBridge {
public:
    // Expose DOM to JavaScript
    void bindDOM(TurboScript::VM* vm, HTMLParser::DOMBuilder::Node* root);
    
    // Expose document object
    void createDocumentObject(TurboScript::VM* vm);
    
    // Expose element methods
    void bindElement(TurboScript::VM* vm);
    
    // Event handling
    using EventCallback = std::function<void(const SIMDString& type, HTMLParser::DOMBuilder::Node* target)>;
    void registerEventHandler(const SIMDString& event, EventCallback callback);
    
    // Execute script in context
    void executeScript(const char* script, size_t len);
    
private:
    TurboScript::VM* vm_;
    HTMLParser::DOMBuilder::Node* document_;
    std::unordered_map<SIMDString, std::vector<EventCallback>> event_handlers_;
};

} // namespace Vortex
