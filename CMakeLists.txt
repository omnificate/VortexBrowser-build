# Vortex Browser Engine CMake Build System
# Supports iOS, macOS, and Linux (with Metal/ANGLE fallback)

cmake_minimum_required(VERSION 3.20)
project(VortexBrowser VERSION 1.0.0 LANGUAGES CXX OBJC OBJCXX)

# C++20 Standard
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Options
option(VORTEX_BUILD_IOS "Build for iOS" OFF)
option(VORTEX_BUILD_MACOS "Build for macOS" OFF)
option(VORTEX_BUILD_TESTS "Build tests" ON)
option(VORTEX_ENABLE_SIMD "Enable SIMD optimizations" ON)
option(VORTEX_ENABLE_METAL "Enable Metal rendering" ON)

# Platform detection
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(VORTEX_BUILD_IOS ON)
elseif(CMAKE_SYSTEM_NAME STREQUAL "Darwin")
    set(VORTEX_BUILD_MACOS ON)
endif()

# Compiler flags
if(VORTEX_ENABLE_SIMD)
    if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
        add_compile_options(-march=armv8-a+crc+crypto)
    endif()
endif()

# Source files
set(VORTEX_ENGINE_SOURCES
    src/Engine.cpp
    src/Layout.cpp
    src/CSS.cpp
)

set(VORTEX_RENDERER_SOURCES
    src/Renderer.mm
)

set(VORTEX_APP_SOURCES
    platform/iOS/main.m
    src/VortexBrowserApp.mm
)

set(VORTEX_HEADERS
    include/vortex/Core.h
    include/vortex/Layout.h
    include/vortex/CSS.h
    include/vortex/Renderer.h
    include/vortex/HTMLParser.h
    include/vortex/JavaScript.h
    include/vortex/VortexBrowserApp.h
)

# Include directories
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/include
    ${CMAKE_CURRENT_SOURCE_DIR}/platform/iOS
)

# iOS/macOS Build
if(VORTEX_BUILD_IOS OR VORTEX_BUILD_MACOS)
    # Find frameworks
    find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
    find_library(UIKIT_LIBRARY UIKit REQUIRED)
    find_library(METAL_LIBRARY Metal REQUIRED)
    find_library(METALKIT_LIBRARY MetalKit REQUIRED)
    find_library(QUARTZ_LIBRARY QuartzCore REQUIRED)
    find_library(COREGRAPHICS_LIBRARY CoreGraphics REQUIRED)
    find_library(CORETEXT_LIBRARY CoreText REQUIRED)
    
    set(VORTEX_FRAMEWORKS
        ${FOUNDATION_LIBRARY}
        ${UIKIT_LIBRARY}
        ${METAL_LIBRARY}
        ${METALKIT_LIBRARY}
        ${QUARTZ_LIBRARY}
        ${COREGRAPHICS_LIBRARY}
        ${CORETEXT_LIBRARY}
    )
    
    # Metal shaders
    set(VORTEX_SHADERS
        shaders/VortexShaders.metal
    )
    
    # Add executable
    if(VORTEX_BUILD_IOS)
        add_executable(VortexBrowser
            ${VORTEX_ENGINE_SOURCES}
            ${VORTEX_RENDERER_SOURCES}
            ${VORTEX_APP_SOURCES}
            ${VORTEX_HEADERS}
        )
        
        # iOS specific settings
        set_target_properties(VortexBrowser PROPERTIES
            MACOSX_BUNDLE YES
            MACOSX_BUNDLE_INFO_PLIST ${CMAKE_CURRENT_SOURCE_DIR}/platform/iOS/Info.plist
            XCODE_ATTRIBUTE_CODE_SIGN_ENTITLEMENTS ${CMAKE_CURRENT_SOURCE_DIR}/platform/iOS/VortexBrowser.entitlements
            XCODE_ATTRIBUTE_CLANG_ENABLE_OBJC_ARC YES
            XCODE_ATTRIBUTE_CLANG_ENABLE_MODULES YES
            XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET "14.0"
            XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY "1,2"
        )
    else()
        # macOS app
        add_executable(VortexBrowser
            ${VORTEX_ENGINE_SOURCES}
            ${VORTEX_RENDERER_SOURCES}
        )
    endif()
    
    target_link_libraries(VortexBrowser ${VORTEX_FRAMEWORKS})
    
    # Compile Metal shaders
    if(VORTEX_ENABLE_METAL AND VORTEX_SHADERS)
        set(METALLIB_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/VortexShaders.metallib")
        
        add_custom_command(
            OUTPUT ${METALLIB_OUTPUT}
            COMMAND xcrun -sdk ${CMAKE_OSX_SYSROOT} metal -c ${VORTEX_SHADERS} -o ${CMAKE_CURRENT_BINARY_DIR}/shaders.air
            COMMAND xcrun -sdk ${CMAKE_OSX_SYSROOT} metallib ${CMAKE_CURRENT_BINARY_DIR}/shaders.air -o ${METALLIB_OUTPUT}
            DEPENDS ${VORTEX_SHADERS}
            COMMENT "Compiling Metal shaders"
        )
        
        add_custom_target(VortexShaders DEPENDS ${METALLIB_OUTPUT})
        add_dependencies(VortexBrowser VortexShaders)
    endif()
else()
    # Linux/other - build just the engine for testing
    add_library(vortex_engine STATIC
        ${VORTEX_ENGINE_SOURCES}
    )
    
    if(VORTEX_BUILD_TESTS)
        add_subdirectory(tests)
    endif()
endif()

# Compiler warnings
if(CMAKE_CXX_COMPILER_ID MATCHES "AppleClang|Clang|GNU")
    target_compile_options(VortexBrowser PRIVATE
        -Wall
        -Wextra
        -Wpedantic
        -Wno-unused-parameter
        -Wno-missing-braces
    )
endif()

# Optimization flags
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(VortexBrowser PRIVATE -O3 -flto)
    target_link_options(VortexBrowser PRIVATE -flto)
elseif(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_compile_options(VortexBrowser PRIVATE -O0 -g)
endif()

# Installation
if(VORTEX_BUILD_IOS)
    install(TARGETS VortexBrowser
        BUNDLE DESTINATION .
        COMPONENT Runtime
    )
    
    # Install shader library
    install(FILES ${METALLIB_OUTPUT}
        DESTINATION VortexBrowser.app
        COMPONENT Runtime
    )
endif()

# CPack for packaging
set(CPACK_PACKAGE_NAME "VortexBrowser")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "High-performance browser engine")
include(CPack)
