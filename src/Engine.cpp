#include "vortex/Engine.h"
#include <iostream>
#include <chrono>

namespace Vortex {

VortexEngine::VortexEngine()
    : viewport_width_(1920)
    , viewport_height_(1080)
    , needs_layout_(false)
    , needs_render_(false)
    , needs_styles_(false)
    , last_frame_time_(0)
    , avg_fps_(60)
    , shutdown_flag_(false)
{
}

VortexEngine::~VortexEngine() {
    shutdown();
}

bool VortexEngine::initialize() {
    html_parser_ = std::make_unique<HTMLParser>();
    css_parser_ = std::make_unique<CSSParser>();
    style_engine_ = std::make_unique<StyleEngine>();
    layout_engine_ = std::make_unique<LayoutEngine>();
    js_engine_ = std::make_unique<TurboScript>();
    js_vm_ = std::make_unique<TurboScript::VM>();
    
    // Start background layout thread
    layout_thread_ = std::thread(&VortexEngine::backgroundLayoutWorker, this);
    
    return true;
}

void VortexEngine::shutdown() {
    shutdown_flag_ = true;
    if (layout_thread_.joinable()) {
        layout_thread_.join();
    }
}

void VortexEngine::loadHTML(const std::string& html) {
    document_ = html_parser_->parse(html);
    needs_layout_ = true;
    needs_styles_ = true;
}

void VortexEngine::loadCSS(const std::string& css) {
    auto rules = css_parser_->parse(css);
    style_engine_->addRules(rules);
    needs_styles_ = true;
}

void VortexEngine::executeJS(const std::string& js) {
    auto ast = js_engine_->parse(js);
    auto bytecode = js_engine_->compile(ast);
    js_vm_->execute(bytecode);
}

void VortexEngine::renderFrame() {
    auto start = std::chrono::high_resolution_clock::now();
    
    processUpdates();
    
    if (needs_render_ && renderer_ && layout_root_) {
        renderer_->beginFrame();
        renderer_->clear(Color(1, 1, 1, 1));
        renderer_->renderLayoutBox(layout_root_);
        renderer_->endFrame();
        needs_render_ = false;
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    last_frame_time_ = std::chrono::duration<float, std::milli>(end - start).count();
    avg_fps_ = 0.95f * avg_fps_ + 0.05f * (1000.0f / last_frame_time_);
}

void VortexEngine::resizeViewport(float width, float height) {
    viewport_width_ = width;
    viewport_height_ = height;
    needs_layout_ = true;
}

void VortexEngine::processUpdates() {
    if (needs_styles_ && document_) {
        style_engine_->computeStyles(document_);
        needs_styles_ = false;
        needs_layout_ = true;
    }
    
    if (needs_layout_ && document_) {
        layout_root_ = layout_engine_->buildLayoutTree(document_);
        layout_engine_->performLayout(layout_root_, viewport_width_);
        needs_layout_ = false;
        needs_render_ = true;
    }
}

void VortexEngine::backgroundLayoutWorker() {
    while (!shutdown_flag_) {
        // Background processing can happen here
        std::this_thread::sleep_for(std::chrono::milliseconds(16));
    }
}

void VortexEngine::invalidateLayout() {
    needs_layout_ = true;
}

void VortexEngine::invalidateStyles() {
    needs_styles_ = true;
}

void VortexEngine::invalidateRender() {
    needs_render_ = true;
}

void VortexEngine::triggerGarbageCollection() {
    // Stub implementation
}

size_t VortexEngine::getMemoryUsage() const {
    return 0;
}

void VortexEngine::setMemoryLimit(size_t bytes) {
    // Stub implementation
}

} // namespace Vortex
