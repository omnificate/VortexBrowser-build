# Vortex Browser - Build Makefile
# Simplified build system for iOS sideloading

.PHONY: all clean ios macos test help

# Configuration
PROJECT_NAME := VortexBrowser
BUILD_DIR := build
XCODE_PROJ := platform/iOS/VortexBrowser.xcodeproj

# Default target
all: help

help:
	@echo "========================================"
	@echo "Vortex Browser Build System"
	@echo "========================================"
	@echo ""
	@echo "Available targets:"
	@echo "  make ios        - Build iOS IPA for sideloading"
	@echo "  make clean      - Clean build artifacts"
	@echo "  make test       - Run unit tests (native)"
	@echo "  make analyze    - Run static analysis"
	@echo "  make docs       - Generate documentation"
	@echo ""
	@echo "Direct build:"
	@echo "  ./scripts/build-ios.sh"
	@echo ""

ios:
	@echo "Building Vortex Browser for iOS..."
	@bash scripts/build-ios.sh

macos:
	@echo "Building Vortex Browser for macOS..."
	@mkdir -p $(BUILD_DIR)
	@cd $(BUILD_DIR) && cmake .. -DVORTEX_BUILD_MACOS=ON
	@cd $(BUILD_DIR) && make -j$(shell sysctl -n hw.ncpu)

test:
	@echo "Running unit tests..."
	@mkdir -p $(BUILD_DIR)/tests
	@$(CXX) -std=c++20 -I include tests/test_engine.cpp src/Engine.cpp src/Layout.cpp src/CSS.cpp -o $(BUILD_DIR)/tests/test_runner
	@$(BUILD_DIR)/tests/test_runner

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf $(BUILD_DIR)
	@echo "✓ Clean complete"

analyze:
	@echo "Running static analysis..."
	@xcodebuild -project $(XCODE_PROJ) -scheme VortexBrowser analyze

docs:
	@echo "Generating documentation..."
	@mkdir -p docs
	@echo "# Vortex Browser Documentation" > docs/README.md
	@echo "## Architecture" >> docs/README.md
	@echo "See DESIGN.md for detailed architecture documentation" >> docs/README.md

install-deps:
	@echo "Checking dependencies..."
	@which xcodebuild > /dev/null || (echo "Error: Xcode not installed" && exit 1)
	@which cmake > /dev/null || (echo "Warning: cmake not installed (optional)" && exit 0)
	@echo "✓ All required dependencies found"

# Quick build for development
dev:
	@mkdir -p $(BUILD_DIR)
	@clang++ -std=c++20 -I include -DNDEBUG \
		-O3 -arch arm64 \
		-isysroot $(shell xcrun --sdk iphoneos --show-sdk-path) \
		-mios-version-min=14.0 \
		-c src/Engine.cpp -o $(BUILD_DIR)/Engine.o

print-info:
	@echo "Project: $(PROJECT_NAME)"
	@echo "Version: 1.0.0"
	@echo "Target: iOS 14.0+ (arm64)"
	@echo "Status: Ready for build"
