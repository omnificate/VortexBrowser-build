#pragma once
#include "HTMLParser.h"
#include "CSS.h"
#include "Layout.h"
#include "JavaScript.h"
#include "Renderer.h"
#include <memory>
#include <string>
#include <atomic>
#include <thread>

namespace Vortex {

class VortexEngine {
public:
    VortexEngine();
    ~VortexEngine();
    
    bool initialize();
    void shutdown();
    
    // Document loading
    void loadHTML(const std::string& html);
    void loadCSS(const std::string& css);
    void executeJS(const std::string& js);
    
    // Rendering
    void renderFrame();
    void resizeViewport(float width, float height);
    
    // Memory management
    void triggerGarbageCollection();
    size_t getMemoryUsage() const;
    void setMemoryLimit(size_t bytes);
    
    // Performance metrics
    float getLastFrameTime() const { return last_frame_time_; }
    float getAverageFPS() const { return avg_fps_; }
    
    // Incremental updates
    void invalidateLayout();
    void invalidateStyles();
    void invalidateRender();
    
private:
    std::unique_ptr<HTMLParser> html_parser_;
    std::unique_ptr<CSSParser> css_parser_;
    std::unique_ptr<StyleEngine> style_engine_;
    std::unique_ptr<LayoutEngine> layout_engine_;
    std::unique_ptr<TurboScript> js_engine_;
    std::unique_ptr<TurboScript::VM> js_vm_;
    std::unique_ptr<MetalRenderer> renderer_;
    
    DOMNodePtr document_;
    std::shared_ptr<LayoutBox> layout_root_;
    
    float viewport_width_;
    float viewport_height_;
    
    std::atomic<bool> needs_layout_;
    std::atomic<bool> needs_render_;
    std::atomic<bool> needs_styles_;
    
    float last_frame_time_;
    float avg_fps_;
    
    std::thread layout_thread_;
    std::atomic<bool> shutdown_flag_;
    
    void processUpdates();
    void backgroundLayoutWorker();
};

// Memory pool for fast allocations
class MemoryPool {
public:
    MemoryPool(size_t block_size, size_t num_blocks);
    ~MemoryPool();
    
    void* allocate(size_t size);
    void deallocate(void* ptr);
    void reset();
    
    size_t getUsed() const { return used_; }
    size_t getCapacity() const { return capacity_; }
    
private:
    struct Block {
        char* memory;
        size_t size;
        size_t used;
        Block* next;
    };
    
    Block* current_block_;
    Block* block_list_;
    size_t block_size_;
    size_t used_;
    size_t capacity_;
    
    void allocateNewBlock();
};

// Lock-free ring buffer for render commands
class CommandRingBuffer {
public:
    CommandRingBuffer(size_t capacity);
    ~CommandRingBuffer();
    
    bool push(const RenderCommand& cmd);
    bool pop(RenderCommand& cmd);
    bool isEmpty() const;
    bool isFull() const;
    
private:
    RenderCommand* buffer_;
    size_t capacity_;
    std::atomic<size_t> head_;
    std::atomic<size_t> tail_;
};

} // namespace Vortex
